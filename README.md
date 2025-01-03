# 🌟 **SysMaven**  
**Empowering IT Mastery**  

![SysMaven Logo](SysMaven.webp)

Welcome to **SysMaven**, the ultimate platform for managing IT systems and assets end-to-end. Designed for small IT teams and SMBs, SysMaven simplifies imaging, patching, and provisioning tasks while providing full control over your IT environment. Built on the robust .NET 8+ framework, it's a tool you can trust.  

---

## 🚀 **Features**

- 🖥️ **IT Asset Management**: Easily track and manage hardware and software inventory.  
- 💽 **Imaging & Deployment**: Simplify system imaging with headless boot support for seamless deployments.  
- 🔒 **Patch Management**: Stay secure and up-to-date with effortless system patching.  
- 📦 **Application Provisioning**: Automate software installation using tools like Ninite.  

---

## 📖 **Getting Started**

### **Prerequisites**

- .NET 8+  
- SQL Server or PostgreSQL for database management  

### **Installation**

1. Clone the repository:  
   ```bash
   git clone https://github.com/yourusername/sysmaven.git
   cd sysmaven
   ```
2. Install dependencies:  
   ```bash
   dotnet restore
   ```
3. Run the application:  
   ```bash
   dotnet run
   ```

---

## 🔧 **How It Works**

1. **Setup Your Environment**: Configure your database and connect your assets.  
2. **Manage Assets**: Use SysMaven's dashboard to track, organize, and monitor systems.  
3. **Deploy and Patch**: Create and deploy images, manage updates, and provision applications.  

---

## 💡 **Why SysMaven?**

- Designed for **small IT teams** and **SMBs**.  
- Built with the latest **.NET 8+ technologies**.  
- Combines asset management, imaging, and application provisioning in one powerful platform.  

---

## ⚠️ **Licensing**

SysMaven is a **source-available** project.  

- **Testing/Personal Use Only**: The source code is provided for personal and testing purposes.  
- **No Commercial Use**: Commercial or production use is prohibited without explicit permission.  
- **All Rights Reserved**: The author retains all rights to the code and project.  

Please see the [LICENSE](LICENSE) file for full details.  

---

## 🤝 **Contributing**

We welcome contributions!  

- Review our guidelines in the [CONTRIBUTING.md](CONTRIBUTING.md) file.  
- Fork the repository and submit a pull request.  

---

## 📬 **Contact**

For questions or inquiries, please reach out to:  
[Your Email Address]  

---

### 💻 **Built With**

- .NET 8+  
- SQL Server / PostgreSQL  

---

## 📦 **ImagingService Deployment**

The `ImagingService` is a core component of SysMaven that handles the imaging and deployment of systems. It is included in the Dockerfile and can be deployed as part of the SysMaven setup.

### **Dockerfile Configuration**

The `Dockerfile` has been updated to include the `ImagingService`. The relevant steps are:

1. Copy `ImagingService.dll` to `/opt/imaging-service/`:
   ```dockerfile
   COPY ImagingService.dll /opt/imaging-service/
   ```

2. Set the working directory to `/opt/imaging-service/`:
   ```dockerfile
   WORKDIR /opt/imaging-service/
   ```

3. Run the `ImagingService` as the entry point:
   ```dockerfile
   ENTRYPOINT ["dotnet", "ImagingService.dll"]
   ```

### **Building and Running the Docker Image**

1. Build the Docker image:
   ```bash
   docker build -t sysmaven:latest .
   ```

2. Run the Docker container:
   ```bash
   docker run -d --name sysmaven -p 8080:80 sysmaven:latest
   ```

Thank you for exploring **SysMaven**! Let's simplify IT together. 🌟
