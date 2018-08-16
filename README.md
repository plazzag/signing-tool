<div align="center">
<img src="/SigningTool/Assets.xcassets/AppIcon.appiconset/icon_128@2x.png" alt="Signing Tool Logo"><br><br>


[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/fastlane/fastlane/blob/master/LICENSE)
![version](https://img.shields.io/badge/macOS-10.13+-green.svg?style=flat)
[![Swift](https://img.shields.io/badge/Swift-4.1-orange.svg?style=flat)](https://developer.apple.com/swift/)
</div>

# Mobile Event App Signing Tool

__Requirement__: macOS 10.13 High Sierra or higher

### Development Environment
* macOS 10.13 High Sierra
* Xcode 9.3
* Swift 4.1

## What is MEA Signing Tool?
**MEA Signing Tool** is a tool that allows you to simplify the manual signing processes of your custom **Mobile Event App** with your own Provisioning Profiles.

## Installing  MEA Signing Tool
There's two main ways to install **MEA Signing Tool**:

1. Download the [latest release](https://github.com/plazzag/signing-tool/releases), open the **SigningTool.pkg** and install the application to your `/Applications` folder.
2. Build it from source, but this is not recommended if your are only going to use **MEA Signing Tool** in the regular way. 

## How does it work?

<p align="center">
<img src="SupportingFiles/MainView.png" style="width: 75%;">
</p>

With the **MEA Signing Tool** you have the possibility to sign the **Mobile Event App** by yourself. The tool supports already signed apps and unsigned Xcode archives of the **Mobile Event App**. This process is necessary if you want to distribute your event app through your own Apple Developer Account.

First of all you need your individual **Mobile Event App**, which you can get from our support team. You will receive either a **.ipa** or **.xcarchive** file that you can use with this tool.

<img style="float: right; margin:0 10px 10px 0" src="SupportingFiles/Requirements.png">

After opening the **MEA Signing Tool** , it checks various preconditions. These requirements are indicated with a green or red status icon.

All requirements must be satisfied for the tool to be used properly. On startup, the Xcode Command Line Tools are searched for. If they are not installed, please install them.</p>

**Installing Command Line Tools in macOS**

1. Launch the Terminal, found in /Applications/Utilities/
2. Type the following command string: ```xcode-select --install```
3. A software update popup window will appear that asks: "The xcode-select command requires the command line developer tools. Would you like to install the tools now?" Confirm this by clicking "Install".

For the other two requirements drag and drop the corresponding files into the marked area inside the **MEA Signing Tool**.

You can create and download your own Provisioning Profile from the [Apple Developer Portal](https://developer.apple.com). In order for this tool to be able to use the profile for signing, the appropriate Distribution Certificate must also be installed on the Keychain of your Mac. The Distribution Certificate consists of a public-private key pair that Apple creates for you. **The private key must be present in the Keychain!**

The **Mobile Event App** needs an App-ID configured to the following services:

* Data Protection: Protected Until First User Authentication
* Push Notifications: enabled
* Wallet: enabled

If all requirements are fulfilled, the app can be signed by clicking "Create App". The bundle identifier of the iOS app is automatically adapted to the bundle identifier in the Provisioning Profile. 

## License

This project is licensed under the terms of the MIT license. See the [LICENSE](LICENSE) file.
