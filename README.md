# TesDash - Tesla Stats Dashboard
Welcome to the TesDash! TesDash is a set of free, open source scripts that captures various Tesla metrics and visualizes the data. The great thing about TesDash is that all data is collected within your own computer so no chance of your credentials and data getting leaked online! Once set up, the dashboard can be easily viewed in the web browser of your choosing. If this dashboard proves useful to you, please consider using my referral link on your future Tesla purchase: https://ts.la/junhyuk52504

## Supported Operating Systems
- Windows (Win 8 or greater)
- Mac (Planned)
- Linux (Planned)

## Supported Browsers
- Edge
- Chrome
- Opera
- Safari (Planned)

## Install steps
1. Download the contents of this repo (Look for the green "Code" download button on the right and "Download ZIP").
2. Open the downloaded zip file and identify the "Windows" folder.
2. Create a local folder (example: C:\TeslaData) and copy everything inside the downloaded "Windows" folder to this folder.
3. From within the local folder, run setup.bat as administrator (Right click on setup.bat then select "Run as administrator").
4. Setup should be complete. To validate open Task Scheduler (Task Scheduler can be searched for within the search bar) and verify that the two "Tesla Data Collection" and "Tesla Data Backup" tasks appear and are enabled.

## Setup steps
1. From the local folder, locate and open "settings.js"
2. Fill in your LoginEmail and LoginPassword using the login for your Tesla account
3. You're done! So easy. To start viewing your data, open index.html on your favorite (supported) browser. Please give a few minutes for your data to start populating in the beginning.

## Configurable settings
While the vehicle is active, TesDash will continuously ping the car for additional data. However, when the vehicle is not in use TesDash will allow the vehicle to go to sleep for battery conservation. In inactive mode, TesDash by default will wake up the vehicle once every 2 hours (7200 seconds) for data collection. To change this default wake interval, modify the "ForceWakeInterval" from "settings.js" to the desired time in seconds.

## Recommended advanced configuration
- Access your dashboard online by enabling web app services using IIS(Internet Information Services). Great for seeing your data on the go on your mobile device. Instructions on how to set this up to come soon.
- If you don't mind spending some money for convenience, you can also utilize cloud services such as AWS and Azure to "host" your dashboard so that your computer doesn't always have to be running. Instructions on how to set this up to come soon.

## Disclaimers
- For TesDash to actively collect data around your vehicle, the computer you installed TesDash must be on at all times. Otherwise you will see gaps in your data. To remove or stop TesDash data collection, simply delete the two tasks mentioned above from Task Scheduler.
- Using TesDash keeps all your Credentials and data within your own computer so it should be secure. However, this does not mean it's foolproof. If you ever feel that your information has been compromised, immediately remove TesDash and change your password on Tesla.com.
