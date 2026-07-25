using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace BurnInApp
{
    /// <summary>
    /// Settings for BurnIn
    /// Data which is to be stored between sessions
    /// Converted from MATLAB class by Torsten Blochwitz Electronics & Software for InfraSolid
    /// </summary>
    public class BurnInSettings
    {
        // Properties
        public string DMM6500_ID { get; set; } = "USB0::0x05E6::0x6500::04546108::INSTR";
        public string MBC_Port { get; set; } = "COM";
        public int I2CAddrOffset { get; set; } = 0;
        public string Folder { get; set; } = "C:\\temp";
        public string Postfix { get; set; } = "Measurement";
        public string FileName { get; set; } = "";
        public string FolderStatus { get; set; } = "C:\\temp";
        public string FolderBurnInProfiles { get; set; } = "C:\\temp";
        public int NumberOfMeasurementsForMeanValues { get; set; } = 5;
        public bool StoreSelfTestResult { get; set; } = true;
        public int StoreSelfTestResultPeriod { get; set; } = 30; // in minutes
        public int BrightnessPosLEDs { get; set; } = 50; // in percent
        public int BrightnessStatusLEDs { get; set; } = 50;
        public string[] IPAddress { get; set; } = new string[] { "192.168.2.30", "", "", "", "", "", "", "" };

        [JsonConverter(typeof(JsonStringEnumConverter))]
        public MBCModeEnum MBCmode { get; set; } = MBCModeEnum.I2C;

        [JsonIgnore]
        public bool ComSettingsHaveChanged { get; set; } = false;

        /// <summary>
        /// Constructor - initializes settings and loads from file if it exists
        /// </summary>
        /// <param name="fileName">Path to the settings JSON file</param>
        public BurnInSettings(string fileName)
        {
            // Set platform-specific default folders
            if (OperatingSystem.IsWindows())
            {
                Folder = "C:\\temp";
                Postfix = "Measurement";
                FolderStatus = "C:\\temp";
                FolderBurnInProfiles = "C:\\temp";
            }
            else
            {
                Folder = "~/BurnInApp/";
                Postfix = "Measurement";
                FolderStatus = "~/BurnInApp/Status/";
                FolderBurnInProfiles = "~/BurnInApp/Profiles/";
            }

            FileName = fileName;
            LoadFromFile(fileName);
        }

        /// <summary>
        /// Parameterless constructor for JSON deserialization
        /// </summary>
        public BurnInSettings()
        {
            // Set platform-specific default folders
            if (OperatingSystem.IsWindows())
            {
                Folder = "C:\\temp";
                Postfix = "Measurement";
                FolderStatus = "C:\\temp";
                FolderBurnInProfiles = "C:\\temp";
            }
            else
            {
                Folder = "~/BurnInApp/";
                Postfix = "Measurement";
                FolderStatus = "~/BurnInApp/Status/";
                FolderBurnInProfiles = "~/BurnInApp/Profiles/";
            }
        }

        /// <summary>
        /// Saves all settings to a JSON file
        /// </summary>
        /// <param name="fileName">Path to the settings file</param>
        /// <returns>True if successful, false otherwise</returns>
        public bool SaveToFile(string fileName)
        {
            try
            {
                // Ensure .json extension
                if (!fileName.Contains(".json", StringComparison.OrdinalIgnoreCase))
                {
                    fileName = fileName + ".json";
                }

                FileName = fileName;

                // Extract folder and create if it doesn't exist
                string? folderSettings = Path.GetDirectoryName(fileName);
                if (!string.IsNullOrEmpty(folderSettings))
                {
                    if (!Directory.Exists(folderSettings))
                    {
                        try
                        {
                            Directory.CreateDirectory(folderSettings);
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"Folder: {folderSettings} could not be created! Cannot store the settings file! Error: {ex.Message}");
                            return false;
                        }
                    }
                }

                // Serialize to JSON with indentation for readability
                var options = new JsonSerializerOptions
                {
                    WriteIndented = true,
                    Converters = { new JsonStringEnumConverter() }
                };

                string jsonString = JsonSerializer.Serialize(this, options);
                File.WriteAllText(fileName, jsonString);

                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Settings could not be saved to {fileName}. Error: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Loads all settings from a JSON file
        /// </summary>
        /// <param name="fileName">Path to the settings file</param>
        public void LoadFromFile(string fileName)
        {
            try
            {
                // Ensure .json extension
                if (!fileName.Contains(".json", StringComparison.OrdinalIgnoreCase))
                {
                    fileName = fileName + ".json";
                }

                if (!File.Exists(fileName))
                {
                    Console.WriteLine($"Settings file {fileName} does not exist. Using default settings.");
                    return;
                }

                // Deserialize from JSON
                var options = new JsonSerializerOptions
                {
                    Converters = { new JsonStringEnumConverter() }
                };

                string jsonString = File.ReadAllText(fileName);
                var loadedSettings = JsonSerializer.Deserialize<BurnInSettings>(jsonString, options);

                if (loadedSettings != null)
                {
                    // Copy all properties from loaded settings
                    DMM6500_ID = loadedSettings.DMM6500_ID;
                    MBC_Port = loadedSettings.MBC_Port;
                    I2CAddrOffset = loadedSettings.I2CAddrOffset;
                    Folder = loadedSettings.Folder;
                    Postfix = loadedSettings.Postfix;
                    FolderStatus = loadedSettings.FolderStatus;
                    FolderBurnInProfiles = loadedSettings.FolderBurnInProfiles;
                    NumberOfMeasurementsForMeanValues = loadedSettings.NumberOfMeasurementsForMeanValues;
                    StoreSelfTestResult = loadedSettings.StoreSelfTestResult;
                    StoreSelfTestResultPeriod = loadedSettings.StoreSelfTestResultPeriod;
                    BrightnessPosLEDs = loadedSettings.BrightnessPosLEDs;
                    BrightnessStatusLEDs = loadedSettings.BrightnessStatusLEDs;
                    IPAddress = loadedSettings.IPAddress;
                    MBCmode = loadedSettings.MBCmode;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Settings could not be loaded from {fileName} ({ex.Message}).");
            }
        }

        /// <summary>
        /// Gets the MBC port string based on the mode
        /// </summary>
        /// <returns>The port string or empty string for non-I2C modes</returns>
        public string GetMBCPort()
        {
            if (MBCmode == MBCModeEnum.I2C)
            {
                if (string.IsNullOrEmpty(MBC_Port))
                {
                    return "COM";
                }
                else
                {
                    return MBC_Port;
                }
            }
            else
            {
                return "";
            }
        }
    }
}
