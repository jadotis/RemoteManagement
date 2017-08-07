# RemoteManagement
Collection of Powershell Scripts for Remote Management

```
Scripts modeled off initial template, for handling error flow. 

Scripts include:
  - WebDeploy: 
      - Installs WebAdministration module, and handles error cases. Accesses local or remote instances of IIS WebApplicationPools without        having the need to use the IIS: command. Stops the appPool and waits and Confirms that the appPool is successfully stopped.
      - File Transfers using either local credentials (If executed from a website itself, will take credentials of the owner of the app          pool or provided credentials). 
      - Supports recursive copies and identification of single files using the '.' character.
      - Restarts the AppPool on a successful copy. 
      - Logs the successes and failures and includes size and number of files successfully copied.
      
  - FileCopy:
      - Similar to WebDeploy
  - ServiceDeploy:
     - Exactly the same as Webdeploy except for services
     - Supports both Service Name and Service Display Name as window's treats them differently. Provides lack of headaches if one or the          other is unknown.
```
      
