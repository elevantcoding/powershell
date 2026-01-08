# powershell
Launch Script

This launcher was originally developed to support the deployment of a compiled Microsoft Access application (.accde) across multiple user environments. The script verifies integrity by computing cryptographic hashes of both the source file and the transferred local copy, ensuring full file integrity before execution / app launch. While the initial use case involved Access application distribution, the underlying design is application-agnostic and applicable to any binary or packaged deployment scenario.
