using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Ports;
using System.Linq;
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
        public string Version { get; private set; } = string.Empty;
        public StatusFile? StatusFile { get; private set; }
        public bool Debug { get; set; } = true;

        public bool DUTi2cEnable { get; set; } = true;

        // I2C Address mapping
        public List<I2CAddressMapping> I2CAddresses { get; private set; } = new List<I2CAddressMapping>
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
                    folder = @"C:\Temp\CommunicationStatus";
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
        private (int addr, bool communicate) AdaptAddr(int i2cAddr, int offset)
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
        public void SwitchI2C(int channel)
        {
            if (Mode == MBCModeEnum.I2C && DUTi2cEnable)
            {
                string msg = $"t11{channel:D03}";
                WriteSerial(msg);
            }
        }

        // Helper methods
        private void HandleError(string resp)
        {
            if (!string.IsNullOrEmpty(resp))
            {
                throw new Exception($"MBC Error: {resp}");
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

    // Placeholder classes - you'll need to implement these based on your MATLAB code
    public class TCPClient : IDisposable
    {
        public int NumRepeat { get; set; }
        public TCPClientStatus Status { get; set; } = new TCPClientStatus();
        public string Host { get; set; } = string.Empty;
        public string StrError { get; set; } = string.Empty;

        public void Send(string message) { }
        public string ReceiveLine() { return string.Empty; }
        public bool TryReconnectToServer(int attempts) { return false; }
        public void Dispose() { }
    }

    public class TCPClientStatus
    {
        public TCPClientStatusEnum GetStatus() { return TCPClientStatusEnum.DISCONNECTED; }
    }

    public enum TCPClientStatusEnum
    {
        DISCONNECTED,
        CONNECTED
    }

    public class StatusFile
    {
        public StatusFile(string folder, string name) { }
        public void AddMsg(MsgLevel level, string message) 
        {
            Debug.WriteLine($"[{level}] {message}");
        }
    }

    public enum MsgLevel
    {
        INFO,
        WARNING,
        ERROR
    }
}
