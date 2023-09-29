# NopCommerce - powershell script for one click deploy  

1. copy this deploy script to root folder where NopCommerce instance is hosted
2. define folder where new instance of NopCommerce is available (2nd line in script)
3. define some custom items (files or folders) to backup in list variable **$itemsToBackupCopy**
4. define some large folders to backup by moving folder in list variable **$itemsToBackupMove**  
5. **run deploy script as administrator, following tasks will be executed:**  
   1. web site and application pool will be stopped
   2. backup folder will be created and defined items will be copied/moved to this folder
   3. old web site files will be removed
   4. new version of NopCommerce will be copied to hosting destination
   5. backuped items will be restored (existing files will be replaced by backuped)
   6. web application pool and web site will be started
