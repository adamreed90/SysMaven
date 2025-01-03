# Configuration

This document provides an overview of the configuration settings for the Network Imaging System. The configuration settings are divided into three main categories: Application Settings, Network Settings, and Storage Settings.

## Application Settings

The application settings are defined in the `AppSettings` class and include the following properties:

- `Logging`: Contains settings related to logging.
  - `LogLevel`: Specifies the log level (e.g., "Information", "Warning", "Error").
  - `LogFilePath`: Specifies the path to the log file.
- `Authentication`: Contains settings related to authentication.
  - `JwtSecret`: Specifies the secret key used for JWT authentication.
  - `TokenExpirationMinutes`: Specifies the token expiration time in minutes.
- `ApplicationName`: Specifies the name of the application.
- `Version`: Specifies the version of the application.

## Network Settings

The network settings are defined in the `NetworkSettings` class and include the following properties:

- `BootServerAddress`: Specifies the address of the boot server.
- `MulticastAddress`: Specifies the multicast address for image deployment.
- `MulticastPort`: Specifies the multicast port for image deployment.
- `NetworkInterface`: Specifies the network interface to be used.

## Storage Settings

The storage settings are defined in the `StorageSettings` class and include the following properties:

- `Device`: Specifies the storage device to be used.
- `PartitionType`: Specifies the type of partition (e.g., "primary", "logical").
- `PartitionSize`: Specifies the size of the partition.
- `FileSystem`: Specifies the file system to be used (e.g., "ext4", "xfs").
- `MountPoint`: Specifies the mount point for the partition.
- `VolumeGroup`: Specifies the volume group for LVM.
- `LogicalVolume`: Specifies the logical volume for LVM.
- `LogicalVolumeSize`: Specifies the size of the logical volume.

## Configuration Files

The configuration settings are loaded from the `appsettings.json` file and environment variables. The `ConfigurationProvider` class is responsible for loading and managing the configuration settings.

### Example `appsettings.json`

```json
{
  "AppSettings": {
    "Logging": {
      "LogLevel": "Information",
      "LogFilePath": "/var/log/imaging.log"
    },
    "Authentication": {
      "JwtSecret": "your-secret-key",
      "TokenExpirationMinutes": 60
    },
    "ApplicationName": "Network Imaging System",
    "Version": "1.0.0"
  },
  "NetworkSettings": {
    "BootServerAddress": "192.168.1.1",
    "MulticastAddress": "239.255.0.1",
    "MulticastPort": 12345,
    "NetworkInterface": "eth0"
  },
  "StorageSettings": {
    "Device": "/dev/sda",
    "PartitionType": "primary",
    "PartitionSize": 10485760,
    "FileSystem": "ext4",
    "MountPoint": "/mnt/image",
    "VolumeGroup": "vg0",
    "LogicalVolume": "lv0",
    "LogicalVolumeSize": 10485760
  }
}
```

### Environment Variables

The configuration settings can also be overridden by environment variables. The environment variables should follow the same structure as the `appsettings.json` file, with each level separated by a double underscore (`__`). For example:

- `AppSettings__Logging__LogLevel`
- `AppSettings__Logging__LogFilePath`
- `AppSettings__Authentication__JwtSecret`
- `AppSettings__Authentication__TokenExpirationMinutes`
- `AppSettings__ApplicationName`
- `AppSettings__Version`
- `NetworkSettings__BootServerAddress`
- `NetworkSettings__MulticastAddress`
- `NetworkSettings__MulticastPort`
- `NetworkSettings__NetworkInterface`
- `StorageSettings__Device`
- `StorageSettings__PartitionType`
- `StorageSettings__PartitionSize`
- `StorageSettings__FileSystem`
- `StorageSettings__MountPoint`
- `StorageSettings__VolumeGroup`
- `StorageSettings__LogicalVolume`
- `StorageSettings__LogicalVolumeSize`
```

## Conclusion

This document provides an overview of the configuration settings for the Network Imaging System. The configuration settings are divided into three main categories: Application Settings, Network Settings, and Storage Settings. The settings can be loaded from the `appsettings.json` file and environment variables, and are managed by the `ConfigurationProvider` class.
