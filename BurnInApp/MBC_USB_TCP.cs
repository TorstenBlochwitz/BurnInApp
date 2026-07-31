using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Ports;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace BurnInApp
{
    /// <summary>
    /// MBC which supports serial and TCP/IP based communication
    /// Converted from MATLAB class by Torsten Blochwitz Electronics & Software for InfraSolid
    /// IP Address for Linux: 169.254.2.32
    /// </summary>
    public class MBC_USB_TCP : IDisposable
    {
        // Properties
        public MBCModeEnum Mode { get; private set; } = MBCModeEnum.UNKNOWN;
        public string StrMode { get; private set; } = "I2C";
        public int AddrOffset { get; set; } = 0;
        private SerialPort? _serialPort;
        public string Port { get; private set; } = string.Empty;
        public int Baudrate { get; set; } = 19200;
        public string Status { get; private set; } = "closed";
        public bool CloseFlag { get; set; } = true;

        public TCPClient[] TcpClients { get; private set; }
        public int NumTcpClients { get; } = 8;
        public bool[] TcpClientConnectErrorReported { get; private set; }
        public string IpAddr { get; private set; } = string.Empty;
        public int TcpPort { get; set; } = 50000;

        public double Timeout { get; set; } = 1.0;
        public int NumRepeat { get; set; } = 20;
        public string Version { get; protected set; } = string.Empty;
        public StatusFile? StatusFile { get; private set; }
        public bool Debug { get; set; } = true;

        public bool DUTi2cEnable { get; set; } = true;

        // I2C Address mapping
        public List<I2CAddressMapping> I2CAddresses { get; protected set; } = new List<I2CAddressMapping>
        {
            new I2CAddressMapping(0, I2CAddrProp.DO_NOTHING, I2CAddrProp.DO_NOTHING)
        };

        // Constructor
        public MBC_USB_TCP(params object[] args)
        {
            // Determine if I2C or Ethernet shall be used
            Mode = MBCModeEnum.I2C;

            if (args.Length == 1)
            {
                string? strAddr = args[0]?.ToString();
                if (!string.IsNullOrEmpty(strAddr) && 
                    (string.IsNullOrEmpty(strAddr) || IsIPAddress(strAddr) || 
                     !strAddr.Contains("COM", StringComparison.OrdinalIgnoreCase)))
                {
                    Mode = MBCModeEnum.TCP;
                }
            }

            // Initialize status file
            if (Debug)
            {
                string folder;
                if (OperatingSystem.IsWindows())
                {
                    folder = @"C:\temp\CommunicationStatus";
                }
                else
                {
                    folder = "~/BurnInApp/Status/Communication/";
                }

                if (!Directory.Exists(folder))
                {
                    Directory.CreateDirectory(folder);
                }

                if (Mode == MBCModeEnum.TCP)
                {
                    StatusFile = new StatusFile(folder, "Ethernet Communication");
                }
                else
                {
                    StatusFile = new StatusFile(folder, "I2C Communication");
                }
            }

            // Initialize based on mode
            if (Mode == MBCModeEnum.I2C)
            {
                InitializeSerialMode(args);
            }
            else
            {
                InitializeTcpMode(args);
            }
        }

        private void InitializeSerialMode(object[] args)
        {
            string? strAddr = args.Length > 0 ? args[0]?.ToString() : null;

            if (args.Length == 0 || string.IsNullOrEmpty(strAddr) || 
                strAddr.Contains("COM", StringComparison.OrdinalIgnoreCase))
            {
                if (OperatingSystem.IsWindows())
                {
                    var ports = FindSerialPorts();
                    if (ports.Length == 0)
                    {
                        // No port detected
                    }
                    else if (ports.Length == 1)
                    {
                        Port = ports[0];
                        SerOpen();
                        SerClose();
                        Mode = MBCModeEnum.I2C;
                    }
                    else
                    {
                        // Multiple ports - would need user selection in GUI
                        Port = ports[0]; // Default to first
                        SerOpen();
                        SerClose();
                    }
                }
                else
                {
                    Port = "/dev/ttyUSB-MBC";
                    SerOpen();
                    SerClose();
                    Mode = MBCModeEnum.I2C;
                }
            }
            else
            {
                Mode = MBCModeEnum.UNKNOWN;
                throw new ArgumentException("Arg1 is neither a serial port, nor an IP Address or a COM port name!");
            }
        }

        private void InitializeTcpMode(object[] args)
        {
            string? strAddr = args.Length > 0 ? args[0]?.ToString() : null;
            IpAddr = strAddr ?? string.Empty;

            TcpClients = new TCPClient[NumTcpClients];
            TcpClientConnectErrorReported = new bool[NumTcpClients];

            for (int n = 0; n < NumTcpClients; n++)
            {
                TcpClients[n] = new TCPClient();
                TcpClients[n].NumRepeat = 1;
                TcpClientConnectErrorReported[n] = false;
            }

            Mode = MBCModeEnum.TCP;
            StrMode = "TCP";
        }

        // Serial port methods
        private void SerOpen()
        {
            if (_serialPort != null && _serialPort.IsOpen)
            {
                _serialPort.Close();
            }

            _serialPort = new SerialPort(Port, Baudrate)
            {
                ReadTimeout = (int)(Timeout * 1000),
                WriteTimeout = (int)(Timeout * 1000),
                NewLine = "\r"
            };

            _serialPort.Open();
            Status = "open";
        }

        private void SerClose()
        {
            if (CloseFlag && _serialPort != null && _serialPort.IsOpen)
            {
                _serialPort.Close();
                Status = "closed";
            }
        }

        // Communication methods
        public string WriteSerial(string message)
        {
            if (_serialPort == null || !_serialPort.IsOpen)
            {
                SerOpen();
            }

            _serialPort!.WriteLine(message);
            string resp = _serialPort.ReadLine();

            SerClose();

            // Remove non-printable characters
            return new string(resp.Where(c => c > 32 && c < 127).ToArray());
        }

        public string WriteMessage(string message, int offset)
        {
            string resp = string.Empty;

            if (Mode == MBCModeEnum.I2C)
            {
                bool restore = CloseFlag;
                CloseFlag = false;

                if (_serialPort == null || !_serialPort.IsOpen)
                {
                    SerOpen();
                }

                _serialPort!.WriteLine(message);
                resp = _serialPort.ReadLine();

                CloseFlag = restore;
                SerClose();
            }
            else
            {
                if (TcpClients[offset].Status.GetStatus() == TCPClientStatusEnum.CONNECTED)
                {
                    TcpClients[offset].Send(message);
                    resp = TcpClients[offset].ReceiveLine();
                }
            }

            // Remove non-printable characters
            return new string(resp.Where(c => c > 32 && c < 127).ToArray());
        }

        // I2C Address adaptation
        protected (int addr, bool communicate) AdaptAddr(int i2cAddr, int offset)
        {
            int addr = i2cAddr / 2;
            bool communicate = true;
            int col = Mode == MBCModeEnum.I2C ? 1 : 2; // Column index (0-based)

            var mapping = I2CAddresses.FirstOrDefault(m => m.I2CAddr == i2cAddr);
            if (mapping != null)
            {
                var prop = col == 1 ? mapping.I2CModeProp : mapping.TcpModeProp;
                if (prop == I2CAddrProp.USE_OFFSET)
                {
                    addr = i2cAddr / 2 + offset;
                }
                else if (prop == I2CAddrProp.DO_NOTHING)
                {
                    communicate = false;
                }
            }

            return (addr, communicate);
        }

        // Write bytes to I2C device
        public bool WriteBytesI2C(int addr, int offset, byte[] bytes)
        {
            var (i2cAddr, doWrite) = AdaptAddr(addr, offset);
            if (!doWrite)
            {
                return false;
            }

            SwitchI2C(0);

            StringBuilder str = new StringBuilder();
            foreach (byte b in bytes)
            {
                str.Append(b.ToString("X2"));
            }

            string msg = $"IW_{i2cAddr:X2}{bytes.Length:X3}{str}";

            for (int i = 0; i < NumRepeat; i++)
            {
                try
                {
                    string resp = WriteMessage(msg, offset);

                    if (!string.IsNullOrEmpty(resp))
                    {
                        HandleError(resp);
                    }
                    else
                    {
                        break;
                    }
                }
                catch (Exception e)
                {
                    if (Debug)
                    {
                        string strAddr = offset == 0 ? $"0x{addr:X}" : $"0x{addr:X}, offset = {offset}";
                        StatusFile?.AddMsg(MsgLevel.WARNING, 
                            $"{i + 1}. {StrMode} communication problem in WriteBytesI2C: {e.Message}\naddr = {strAddr}, msg = {msg}\n");
                    }

                    if (Mode == MBCModeEnum.I2C && i > NumRepeat / 2)
                    {
                        if (Debug)
                        {
                            StatusFile?.AddMsg(MsgLevel.WARNING, "\n--> Resetting I2C Bus.\n");
                        }
                        ResetI2C();
                    }

                    if (i == NumRepeat - 1)
                    {
                        throw;
                    }
                }
            }

            return true;
        }

        // Query bytes from I2C device
        public byte[] QueryBytesI2C(int addr, int offset, uint cmd, int nCmd, int nRead)
        {
            var (i2cAddr, _) = AdaptAddr(addr, offset);
            byte[] bytes = new byte[nRead];

            SwitchI2C(0);

            string str = cmd.ToString($"X{nCmd * 2}");
            string msg = $"IQ_{i2cAddr:X2}{nCmd:X3}{nRead:X3}{str}";

            for (int i = 0; i < NumRepeat; i++)
            {
                try
                {
                    string resp = WriteMessage(msg, offset);

                    if (nRead * 2 != resp.Length)
                    {
                        HandleError(resp);
                    }
                    else
                    {
                        for (int index = 0; index < nRead; index++)
                        {
                            bytes[index] = Convert.ToByte(resp.Substring(2 * index, 2), 16);
                        }
                        break;
                    }
                }
                catch (Exception e)
                {
                    if (Debug)
                    {
                        string strAddr = offset == 0 ? $"0x{addr:X}" : $"0x{addr:X}, offset = {offset}";
                        StatusFile?.AddMsg(MsgLevel.WARNING,
                            $"{i + 1}. {StrMode} communication problem in QueryBytesI2C: {e.Message}\naddr = {strAddr}, msg = {msg}\n");
                    }

                    if (Mode == MBCModeEnum.I2C && i > NumRepeat / 2)
                    {
                        if (Debug)
                        {
                            StatusFile?.AddMsg(MsgLevel.WARNING, "\n--> Trying ResetI2C Bus.\n");
                        }
                        ResetI2C();
                    }

                    if (i == NumRepeat - 1)
                    {
                        throw;
                    }
                }
            }

            return bytes;
        }

        // Read bytes from I2C device
        public byte[] ReadBytesI2C(int addr, int offset, int nRead)
        {
            var (i2cAddr, _) = AdaptAddr(addr, offset);
            byte[] bytes = new byte[nRead];

            SwitchI2C(0);

            string msg = $"IR_{i2cAddr:X2}{nRead:X3}";

            for (int i = 0; i < NumRepeat; i++)
            {
                try
                {
                    string resp = WriteMessage(msg, offset);

                    if (nRead * 2 != resp.Length)
                    {
                        HandleError(resp);
                    }
                    else
                    {
                        for (int index = 0; index < nRead; index++)
                        {
                            bytes[index] = Convert.ToByte(resp.Substring(2 * index, 2), 16);
                        }
                        break;
                    }
                }
                catch (Exception e)
                {
                    if (Debug)
                    {
                        string strAddr = offset == 0 ? $"0x{addr:X}" : $"0x{addr:X}, offset = {offset}";
                        StatusFile?.AddMsg(MsgLevel.WARNING,
                            $"{i + 1}. {StrMode} communication problem in ReadBytesI2C: {e.Message}\naddr = {strAddr}, msg = {msg}\n");
                    }

                    if (Mode == MBCModeEnum.I2C && i > NumRepeat / 2)
                    {
                        if (Debug)
                        {
                            StatusFile?.AddMsg(MsgLevel.WARNING, "\n--> Trying ResetI2C Bus.\n");
                        }
                        ResetI2C();
                    }

                    if (i == NumRepeat - 1)
                    {
                        throw;
                    }
                }
            }

            return bytes;
        }

        // Query string
        public string QueryString(int offset, string msg)
        {
            string resp = string.Empty;

            for (int i = 0; i < NumRepeat; i++)
            {
                try
                {
                    resp = WriteMessage(msg, offset);
                    break;
                }
                catch (Exception e)
                {
                    if (Debug)
                    {
                        StatusFile?.AddMsg(MsgLevel.WARNING,
                            $"{i + 1}. {StrMode} communication problem in QueryString: {e.Message}\nmsg = {msg}\n");
                    }

                    if (Mode == MBCModeEnum.I2C && i > NumRepeat / 2)
                    {
                        if (Debug)
                        {
                            StatusFile?.AddMsg(MsgLevel.WARNING, "\n--> Trying ResetI2C Bus.\n");
                        }
                        ResetI2C();
                    }

                    if (i == NumRepeat - 1)
                    {
                        throw;
                    }
                }
            }

            return resp;
        }

        // Get version
        public string GetVersion()
        {
            if (Mode == MBCModeEnum.I2C)
            {
                return WriteSerial("V");
            }
            else
            {
                return QueryString(0, "V");
            }
        }

        // Get error counter
        public string GetErrorCounter(int offset)
        {
            if (Mode == MBCModeEnum.I2C)
            {
                return "0|0";
            }
            else
            {
                return WriteMessage("C", offset);
            }
        }

        // Reset I2C bus
        public void ResetI2C()
        {
            if (Mode == MBCModeEnum.I2C)
            {
                SwitchI2C(0);

                string msg0 = "PS_D00";
                string msg1 = "PS_D01";

                try
                {
                    WriteSerial(msg0);
                    for (int i = 0; i < 8; i++)
                    {
                        WriteSerial(msg1);
                        WriteSerial(msg0);
                    }
                    WriteSerial(msg1);
                }
                catch (Exception e)
                {
                    if (Debug)
                    {
                        StatusFile?.AddMsg(MsgLevel.WARNING,
                            $"I2C communication problem in ResetI2C: {e.Message}\nmsg = {msg0}\n");
                    }
                }
            }
        }

        // Reset
        public void Reset()
        {
            if (Mode == MBCModeEnum.I2C)
            {
                bool restore = CloseFlag;
                CloseFlag = false;

                SwitchI2C(0);
                WriteSerial("R");
                Thread.Sleep(1800);

                _serialPort?.DiscardInBuffer();
                CloseFlag = restore;
            }
        }

        // Switch I2C
        public virtual void SwitchI2C(int channel)
        {
            if (Mode == MBCModeEnum.I2C && DUTi2cEnable)
            {
                string msg = $"t11{channel:D03}";
                WriteSerial(msg);
            }
        }

        // Error codes returned by the MBC (converted from MATLAB CBerror() code table)
        private static readonly Dictionary<string, string> CBErrorCodeTable = new Dictionary<string, string>
        {
            { "001", "no answer from Ethernet or USB" },
            { "002", "interface not supported by this version" },
            { "010", "buffer overflow: transferred string to long" },
            { "011", "selected mode is not allowed" },
            { "012", "invalid input: number of bytes {0 .. 128}d" },
            { "013", "invalid input: trigger-time {1 .. 999}d" },
            { "014", "action not available; another interface is opened" },
            { "015", "power supply ASIC = OFF! Wait for switching on" },
            { "016", "wrong selection action on selected interface" },
            { "017", "wrong selection speed of interface" },
            { "018", "OWI - wrong selection of open port parameter" },
            { "019", "invalid input: twait {0 .. 65535} d " },
            { "020", "port command - wrong selection of read or write option (2nd character)" },
            { "021", "port command - invalid input for pin or port (3rd character)" },
            { "022", "port command - invalid input: port selection {A ... D" },
            { "023", "port command - invalid input: port state {00 .. FF}h" },
            { "024", "port command - invalid input: pin selection {0 .. 7}d" },
            { "025", "port command - invalid input: pin state {0/1/2]d" },
            { "030", "I²C - Timeout! Master (CB) was not able to drive bus line" },
            { "031", "I²C - start condition not sent" },
            { "032", "I²C - read: no address-ack from slave --> try other I²C device address" },
            { "033", "I²C - read: data not received: No ack from master" },
            { "034", "I²C - read: last byte not correct. Wrong ack from master" },
            { "035", "I²C - read: communication error during data byte transmission" },
            { "036", "I²C - SDA or SCL shorted to GND - no high level on I²C bus --> check KS5V " },
            { "037", "I²C - write: no ack from slave after transmitting byte" },
            { "038", "I²C - write: no address-ack from slave --> try other I²C device address" },
            { "039", "I²C - Length of string from PC doesn't fit to specified lenght. (Check e.g. 'ByteCount' parameter in I2C spreadsheet)" },
            { "040", "LIN - header incorrect" },
            { "041", "OWI/Zacwire - Timeout! ASIC does not answer" },
            { "042", "LIN - CRC incorrect:  received <=> calculated" },
            { "043", "ZACwire - read: data channel not high" },
            { "044", "LIN - wrong selection of action (2nd character)" },
            { "045", "LIN - wrong selection of action (3rd character)" },
            { "046", "LIN - Interface needs to be open before it can be used (--> use \"LO\" command)" },
            { "050", "SPI - header incorrect" },
            { "051", "SPI - Timeout! Master (CB) was not able to drive busline" },
            { "052", "SPI - Timeout during data trasnmission (either read or write)" },
            { "061", "MCB - no seperator (:)" },
            { "062", "MCB - no answer from MCB (serial ACK/NACK)" },
            { "063", "MCB - no high signal on PinD2 (MCB V2.0) or PinD3 (MCB V2.1) before answer of MCB" },
            { "064", "MCB - interface not supported by this firmware version" },
            { "065", "MCB - \"short ACK\" mode of MCB is activated and thus only I2Cor ZACwire commands are allowed after MCB command" },
            { "066", "MCB - No ACK from MCB in \"short ACK\" mode of MCB (no high signal on readback channel between MCB and CB)" },
            { "067", "MCB - No ACK from MCB in \"short ACK\" mode of MCB (no low signal on readback channel between MCB and CB)" },
            { "068", "MCB - firmware version V1.03 and V2.00a/V2.01 connected --> adjustment of timing " },
            { "069", "MCB - firmware version V1.03 and V2.00a/V2.01 connected - timing adjustment wasn't successful" },
            { "080", "ZACwire - invalid input: speed of interface [10...13]d or wrong length of input string" },
            { "081", "ZACwire . wrong action on interface (select either \"read\", \"write\" or \"speed\" interface)" },
            { "082", "ZACwire - wrong selection for trigger or non trigger (\"T\" or \"_\" for 3rd character) write command" },
            { "083", "ZACwire - wrong number of parameters for write command --> check \"ByteCount\" and \"BytesToBeWritten\" in \"ZACwire\"" },
            { "084", "ZACwire - timeout: no high signal found on the ZACwire interface --> check for shorted pin" },
            { "085", "ZACwire - timeout: IC didn't send 1st high-low transistion to send start-bit" },
            { "086", "ZACwire - timeout: low-high edge of start-bit didn't received --> check communication speed or shorted pin" },
            { "087", "ZACwire - timeout: high-low edge at end of start-bit failed" },
            { "088", "ZACwire - timeout: high-low edge at beginning of databit failed" },
            { "089", "ZACwire - timeout: low-high edge at end of databit failed" },
            { "090", "ZACwire - timeout: low-high edge at end of parity bit failed" },
            { "091", "ZACwire - wrong number of parameters for read command --> check \"ReadByteCount\" in \"ZACwire\" tab" },
            { "092", "ZACwire - wrong lenght of read command" },
            { "099", "LIN - wrong selection for \"LOM\" command - either use LOM0, LOM1, or LOM2" },
            { "100", "LIN - wrong version selected" },
            { "101", "LIN - wrong communication speed selected" },
            { "102", "LIN - wrong CRC option selected" },
            { "103", "LIN - wrong option for LIN open interface selected" },
            { "104", "LIN - wrong length of LIN open interface command" },
            { "105", "LIN - write/read: no low signal at trigger command" },
            { "106", "LIN - write/read: no high signal on bus before Break Field should be sent" },
            { "107", "LIN - write/read: no low signal during Break Field" },
            { "108", "LIN - write/read: no high level for stop condition after Break Field" },
            { "109", "LIN - write/read: no low level for start condition of SYNC Field" },
            { "110", "LIN - write/read: no high level for stop condition after SYNC Field" },
            { "111", "LIN - write/read: no low level for start condition of PID" },
            { "112", "LIN - write/read: no high level for stop condition after PID" },
            { "113", "LIN - write: no low level for start condition before Data Field" },
            { "114", "LIN - write: no high level for stop condition after Data Field" },
            { "115", "LIN - write: no low level closeFlag: 1 for start condition before CRC Data Field" },
            { "116", "LIN - write: no high level for stop condition after CRC Data Field" },
            { "117", "LIN - read: no high level for last stop condition (CRC Data Field) of transmission detected" },
            { "118", "LIN - read: no high level for stop condition of PID detected --> Test of PINB.0 at SSC CB" },
            { "119", "LIN - read: no low level for start condition of 1st Data Field from slave detected" },
            { "120", "LIN - read: no high level for stop condition of 1st Data Field from slave detected" },
            { "121", "LIN - read: no low level for start condition of 2nd Data Field from slave detected" },
            { "122", "LIN - read: no high level for stop condition of 2nd Data Field from slave detected" },
            { "123", "LIN - read: no low level for start condition of 3rd Data Field from slave detected" },
            { "124", "LIN - read: no high level for stop condition of 3rd Data Field from slave detected" },
            { "125", "LIN - read: no low level for start condition of 4th Data Field from slave detected" },
            { "126", "LIN - read: no high level for stop condition of 4th Data Field from slave detected" },
            { "127", "LIN - read: no low level for start condition of 5th Data Field from slave detected" },
            { "128", "LIN - read: no high level for stop condition of 5th Data Field from slave detected" },
            { "129", "LIN - read: no low level for start condition of 6th Data Field from slave detected" },
            { "130", "LIN - read: no high level for stop condition of 6th Data Field from slave detected" },
            { "131", "LIN - read: no low level for start condition of 7th Data Field from slave detected" },
            { "132", "LIN - read: no high level for stop condition of 7th Data Field from slave detected" },
            { "133", "LIN - read: no low level for start condition of 8th Data Field from slave detected" },
            { "134", "LIN - read: no high level for stop condition of 8th Data Field from slave detected" },
            { "135", "LIN - read: no low level for start condition of CRC Data Field from slave detected" },
            { "140", "analog read - wrong value channel: channel selection {0 .. 4" },
            { "150", "OWI - wrong length of OWI read command" },
            { "151", "OWI - wrong selection for OWI read bytes" },
            { "160", "I²C - query: no repeated start condition on the bus" },
            { "161", "I²C - query: no address ACK from slave" },
            { "162", "I²C - query: no data ACK from slave" },
            { "163", "I²C - query: master could not put NACK on the bus" },
            { "200", "SENT - open: wrong command length" },
            { "201", "SENT - open: wrong selection of 3rd character " },
            { "202", "SENT - open: wrong selection of used SENT interface pin" },
            { "203", "SENT - open: wrong selection of TICK time - TICK Time will now be measured automatically" },
            { "204", "SENT - open: wrong selection for check of TICK time - TICK Time will now be measured automatically & Limit is set to 0" },
            { "205", "SENT - open: wrong sele closeFlag: 1ction of number of nibbles in the data stream - lower limitation" },
            { "206", "SENT - open: wrong selection of number of nibbles in the data stream - upper limitation" },
            { "207", "SENT - open: wrong selection for CRC check enabled" },
            { "208", "SENT - open: wrong selection for CRC version" },
            { "209", "SENT - open: wrong selection for additional string \"0000\" at the end of the SENT open command" },
            { "210", "SENT - open: wrong selection of SENT data formating" },
            { "219", "SENT - measure TICK time: wrong command length" },
            { "220", "SENT - measure TICK time: no high signal on the SENT interface " },
            { "221", "SENT - measure TICK time: no high-low transmission found" },
            { "222", "SENT - measure TICK time: no low-high transmission found" },
            { "223", "SENT - measure TICK time: measured low impuls was too long - check TICK time - overflow is caused at 200 µs TICK" },
            { "224", "SENT - measure TICK time: no high signal after initialisation measurement" },
            { "225", "SENT - measure TICK time: no high-low transmission during SYNC search" },
            { "226", "SENT - measure TICK time: more than 255 nibbles tested and no SYNC found" },
            { "230", "SENT - read: invalid input: number of bytes {1 .. 16}d" },
            { "231", "SENT - read: Length of string doesn't fit to specified lenght. (Check e.g. 'ByteCount' parameter in SENT spreadsheet)" },
            { "232", "SENT - read: no TICK time speciefied for comparison with TICK time limits --> check and send SENT open command" },
            { "233", "SENT - read: measured TICK time doesn't fir to specified TICK time --> check range check and specified TICK time" },
            { "234", "SENT - read: no initial high-low transmission found" },
            { "235", "SENT - read: no high-low transmission found for the 2nd acquired data nibble" },
            { "236", "SENT - read: no high-low transmission found for the 3rd acquired data nibble" },
            { "237", "SENT - read: more than 255 nibbles tested and no SYNC found" },
            { "238", "SENT - read: more than 255 nibbles tested and no SYNC found" },
            { "241", "SENT - SDM: Length of string doesn't fit to specified lenght. " },
            { "242", "SENT - SDM: no TICK time speciefied for comparison with TICK time limits --> check and send SENT open command" },
            { "243", "SENT - SDM: measured TICK time doesn't fir to specified TICK time --> check range check and specified TICK time" },
            { "244", "SENT - SDM: no start bit (bit #3) found in the status nibble" },
            { "245", "SENT - SDM: no initial high-low transmission found" },
            { "246", "SENT - SDM: no high-low transmission found for the 2nd acquired data nibble" },
            { "247", "SENT - SDM: no high-low transmission found for the 3rd acquired data nibble" },
            { "248", "SENT - SDM: more than 255 nibbles tested and no SYNC found" },
            { "249", "SENT - SDM: more than 255 nibbles tested and no SYNC found" },
            { "250", "SENT - SDM: invalid input: number of bytes {1 .. 16}d" },
            { "263", "SENT - read: wrong feedback for 4 inverted bits " },
        };

        // Helper methods
        // Converted from MATLAB CBerror(): looks up the error message for the given code
        // and throws an exception with the same format as the original MATLAB error().
        protected void HandleError(string resp)
        {
            if (!string.IsNullOrEmpty(resp))
            {
                string message = CBErrorCodeTable.TryGetValue(resp, out string? msg) ? msg : string.Empty;
                throw new Exception($"{resp}: {message}");
            }
        }

        private bool IsIPAddress(string address)
        {
            return System.Net.IPAddress.TryParse(address, out _);
        }

        private string[] FindSerialPorts()
        {
            return SerialPort.GetPortNames();
        }

        public string GetConnectedPort()
        {
            if (Mode == MBCModeEnum.I2C)
            {
                return Port;
            }
            else
            {
                int n = GetNumberOfConnectedTCPClients();
                return $"{n} Ethernet MBCs";
            }
        }

        public int GetNumberOfConnectedTCPClients()
        {
            int count = 0;
            foreach (var client in TcpClients)
            {
                if (client?.Status?.GetStatus() == TCPClientStatusEnum.CONNECTED)
                {
                    count++;
                }
            }
            return count;
        }

        // Connects the TCP client with the given index (0-based) to the specified server.
        public bool ConnectToTCPServer(int index, string ipAddr, double connectTimeoutSeconds)
        {
            bool ret = false;
            if (Mode == MBCModeEnum.TCP)
            {
                TcpClients[index].ConnectToServer(ipAddr, TcpPort, connectTimeoutSeconds);
                if (TcpClients[index].Status.GetStatus() != TCPClientStatusEnum.CONNECTED)
                {
                    if (!TcpClientConnectErrorReported[index])
                    {
                        StatusFile?.AddMsg(MsgLevel.ERROR, $"Connect to {TcpClients[index].Host} failed: {TcpClients[index].StrError}\n");
                        TcpClientConnectErrorReported[index] = true;
                    }
                    throw new Exception(TcpClients[index].StrError);
                }
                StatusFile?.AddMsg(MsgLevel.INFO, $"Connected {TcpClients[index].Host}\n");
                TcpClientConnectErrorReported[index] = false;
                ret = true;
            }
            return ret;
        }

        // Tries to reconnect to the MBC (serial port in I2C mode or the TCP client with the given index in TCP mode).
        public int TryReconnect(int index = 0)
        {
            if (Mode == MBCModeEnum.I2C)
            {
                for (int i = 1; i <= NumRepeat; i++)
                {
                    Console.WriteLine($"Trying to reconnect: {i} of {NumRepeat}");
                    try
                    {
                        if (_serialPort != null && _serialPort.IsOpen)
                        {
                            _serialPort.Close();
                        }
                        Status = "closed";
                        SerOpen();
                        Reset();
                        return 1;
                    }
                    catch (Exception e)
                    {
                        Console.WriteLine($"Reconnect failed: {e.Message} Waiting...");
                        if (i < 10)
                        {
                            Thread.Sleep((int)(Math.Pow(1.3, i) * 1000));
                        }
                    }
                }

                if (OperatingSystem.IsWindows())
                {
                    for (int i = 1; i <= NumRepeat; i++)
                    {
                        var ports = FindSerialPorts();
                        foreach (var port in ports)
                        {
                            try
                            {
                                Console.WriteLine($"Trying connect to {port}: {i} of {NumRepeat}");
                                using var testPort = new SerialPort(port, 19200) { ReadTimeout = 1000 };
                                testPort.Open();
                                testPort.WriteLine("V");
                                string resp = testPort.ReadLine();
                                testPort.Close();
                                Console.WriteLine($"MBC Version: {resp}");
                                Port = port;
                                SerOpen();
                                Reset();
                                return 1;
                            }
                            catch (Exception e)
                            {
                                Console.WriteLine($"Connect to {port} failed: {e.Message} Waiting...");
                                if (i < 10)
                                {
                                    Thread.Sleep((int)(Math.Pow(1.3, i) * 1000));
                                }
                            }
                        }
                    }
                }
                return 0;
            }
            else
            {
                for (int i = 1; i <= NumRepeat; i++)
                {
                    Console.WriteLine($"\n...Trying to reconnect: {i} of {NumRepeat}");
                    if (TcpClients[index].TryReconnectToServer(10))
                    {
                        StatusFile?.AddMsg(MsgLevel.INFO, $"Reconnected to {TcpClients[index].Host}\n");
                        return 1;
                    }
                    else
                    {
                        Console.WriteLine($"Reconnect failed: Waiting {Math.Pow(1.35, i):F2} s...");
                        StatusFile?.AddMsg(MsgLevel.WARNING, $"Reconnect to {TcpClients[index].Host} failed: {TcpClients[index].StrError}\n");
                        Thread.Sleep((int)(Math.Pow(1.35, i) * 1000));
                    }
                }
                return 0;
            }
        }

        // IDisposable implementation
        public void Dispose()
        {
            _serialPort?.Dispose();
            if (TcpClients != null)
            {
                foreach (var client in TcpClients)
                {
                    client?.Dispose();
                }
            }
        }
    }

    // Supporting classes and enums
    public enum MBCModeEnum
    {
        UNKNOWN,
        I2C,
        TCP
    }

    public enum I2CAddrProp
    {
        DO_NOTHING,
        USE_OFFSET,
        NORMAL
    }

    public class I2CAddressMapping
    {
        public int I2CAddr { get; set; }
        public I2CAddrProp I2CModeProp { get; set; }
        public I2CAddrProp TcpModeProp { get; set; }

        public I2CAddressMapping(int i2cAddr, I2CAddrProp i2cMode, I2CAddrProp tcpMode)
        {
            I2CAddr = i2cAddr;
            I2CModeProp = i2cMode;
            TcpModeProp = tcpMode;
        }
    }

    /// <summary>
    /// TCP client used to communicate with an Ethernet based MBC.
    /// Converted from the MATLAB class TCPClient by Torsten Blochwitz Electronics & Software for InfraSolid.
    /// Uses System.Net.Sockets.TcpClient, so it works the same way on Windows and Linux.
    /// </summary>
    public class TCPClient : IDisposable
    {
        public string Host { get; private set; } = string.Empty;
        public int Port { get; private set; }
        public TCPClientStatus Status { get; } = new TCPClientStatus();
        public string StrError { get; private set; } = string.Empty;
        public int NumRepeat { get; set; } = 10;

        private TcpClient? _client;
        private NetworkStream? _stream;
        private StreamReader? _reader;
        private StreamWriter? _writer;

        public TCPClient()
        {
            Status.SetStatus(TCPClientStatusEnum.DISCONNECTED);
        }

        public bool ConnectToServer(string host, int port, double connectTimeoutSeconds)
        {
            // Do nothing if we are already connected to the same host/port.
            if (Status.GetStatus() == TCPClientStatusEnum.CONNECTED)
            {
                if (!string.Equals(Host, host, StringComparison.Ordinal) || Port != port)
                {
                    Disconnect();
                }
            }

            Host = host;
            Port = port;
            return TryReconnectToServer(connectTimeoutSeconds);
        }

        public bool TryReconnectToServer(double connectTimeoutSeconds)
        {
            StrError = string.Empty;
            try
            {
                try
                {
                    Dns.GetHostAddresses(Host);
                }
                catch (Exception)
                {
                    StrError = $"Error while (re)connecting to {Host}:\nName cannot be resolved.";
                    Status.SetStatus(TCPClientStatusEnum.ERROR);
                    Disconnect();
                    return false;
                }

                if (_client != null && _client.Connected)
                {
                    if (PingServer())
                    {
                        return true;
                    }
                    Disconnect();
                }

                _client = new TcpClient();
                var connectTask = _client.ConnectAsync(Host, Port);
                int timeoutMs = (int)Math.Max(connectTimeoutSeconds * 1000, 100);
                if (!connectTask.Wait(timeoutMs))
                {
                    throw new TimeoutException($"IP address not found! Connection timed out after {connectTimeoutSeconds} s.");
                }

                _client.NoDelay = true; // equivalent of "EnableTransferDelay", false
                _client.ReceiveTimeout = 5000;
                _client.SendTimeout = 5000;

                _stream = _client.GetStream();
                _reader = new StreamReader(_stream, Encoding.ASCII);
                _writer = new StreamWriter(_stream, Encoding.ASCII) { NewLine = "\n", AutoFlush = true };

                Status.SetStatus(TCPClientStatusEnum.CONNECTED);
                return true;
            }
            catch (Exception ex)
            {
                StrError = $"Error while (re)connecting to {Host}:\n{ex.Message} For more information\n";
                Status.SetStatus(TCPClientStatusEnum.ERROR);
                Disconnect();
                return false;
            }
        }

        public void Disconnect()
        {
            try
            {
                _reader?.Dispose();
                _writer?.Dispose();
                _stream?.Dispose();
                _client?.Close();
                _client?.Dispose();
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Could not delete TCP client: {ex.Message}");
            }
            finally
            {
                _reader = null;
                _writer = null;
                _stream = null;
                _client = null;
            }
        }

        public bool PingServer()
        {
            if (Status.GetStatus() != TCPClientStatusEnum.CONNECTED)
            {
                return false;
            }

            try
            {
                _writer!.WriteLine("P");
                string? pong = _reader!.ReadLine();
                return pong == "Pong";
            }
            catch
            {
                return false;
            }
        }

        public bool Send(string message)
        {
            if (Status.GetStatus() != TCPClientStatusEnum.CONNECTED)
            {
                return false;
            }

            for (int i = 1; i <= NumRepeat; i++)
            {
                try
                {
                    _writer!.WriteLine(message);
                    return true;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"The error: {ex.Message} has occurred during write after: {i}");
                    Status.SetStatus(TCPClientStatusEnum.ERROR);
                    if (i >= NumRepeat)
                    {
                        return false;
                    }
                    if (!TryReconnectToServer(10) && i >= NumRepeat)
                    {
                        return false;
                    }
                }
            }
            return false;
        }

        public bool Receive(int size, out string msg)
        {
            msg = string.Empty;
            if (Status.GetStatus() != TCPClientStatusEnum.CONNECTED)
            {
                return false;
            }

            for (int i = 1; i <= NumRepeat; i++)
            {
                try
                {
                    char[] buffer = new char[size];
                    int totalRead = 0;
                    while (totalRead < size)
                    {
                        int read = _reader!.Read(buffer, totalRead, size - totalRead);
                        if (read == 0)
                        {
                            throw new IOException("Connection closed by remote host.");
                        }
                        totalRead += read;
                    }
                    msg = new string(buffer);
                    return true;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"The error: {ex.Message} has occurred during read after: {i}");
                    Status.SetStatus(TCPClientStatusEnum.ERROR);
                    if (i >= NumRepeat)
                    {
                        return false;
                    }
                    if (!TryReconnectToServer(10) && i >= NumRepeat)
                    {
                        return false;
                    }
                }
            }
            return false;
        }

        public string ReceiveLine()
        {
            if (Status.GetStatus() != TCPClientStatusEnum.CONNECTED)
            {
                return string.Empty;
            }

            for (int i = 1; i <= NumRepeat; i++)
            {
                try
                {
                    return _reader!.ReadLine() ?? string.Empty;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"The error: {ex.Message} has occurred during read after: {i}");
                    Status.SetStatus(TCPClientStatusEnum.ERROR);
                    if (i >= NumRepeat)
                    {
                        return string.Empty;
                    }
                    if (!TryReconnectToServer(10) && i >= NumRepeat)
                    {
                        return string.Empty;
                    }
                }
            }
            return string.Empty;
        }

        public void Dispose()
        {
            Disconnect();
            GC.SuppressFinalize(this);
        }
    }

    /// <summary>
    /// Thread-safe status wrapper for TCPClient. Converted from the MATLAB class TCPClientStatus.
    /// </summary>
    public class TCPClientStatus
    {
        private readonly object _lock = new object();
        private readonly string[] _strStatus = { "ERROR", "Disconnected", "Connected" };
        private TCPClientStatusEnum _status = TCPClientStatusEnum.DISCONNECTED;

        public void SetStatus(TCPClientStatusEnum v)
        {
            lock (_lock)
            {
                _status = v;
            }
        }

        public TCPClientStatusEnum GetStatus()
        {
            lock (_lock)
            {
                return _status;
            }
        }

        public string GetStatusString()
        {
            lock (_lock)
            {
                // _status is -1 (ERROR), 0 (DISCONNECTED) or 1 (CONNECTED)
                return _strStatus[(int)_status + 1];
            }
        }
    }

    public enum TCPClientStatusEnum : sbyte
    {
        ERROR = -1,
        DISCONNECTED = 0,
        CONNECTED = 1
    }
}
