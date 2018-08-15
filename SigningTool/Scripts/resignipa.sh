#!/bin/sh

while [ "$1" != "" ]; do
    case "$1" in
        -a | --app)                 shift
                                    app="$1"
                                    ;;
        -p | --profile )            shift
                                    profileFile="$1"
                                    ;;
        -s | --store )              shift
                                    store="true"
                                    ;;
        -e | --enterprise )         shift
                                    store="false"
                                    ;;
        * )                         exit 1;
    esac
    shift
done

filename=$(basename "$app");
workingDirectory=$(dirname "$app");
datevar=$(date +%Y_%m_%d_%H_%M)

cd "$workingDirectory"

if [[ -z "$app" || -z "$profileFile" || -z "$store" ]]; then
    echo "Script not configured properly"
    exit 1;
fi

rm -rf app.plist identity.txt validation.txt Payload/
echo "Signing process started"

unzip "$app" >&-
if ! [[ -e Payload/MEA.app/Info.plist ]]; then
    echo "There is an issue with the .ipa. Please contact your contact person at plazz AG."
    exit 1;
fi

security cms -D -i "$profileFile" > app.plist 2> /dev/null
profileCheck=$(grep -c "data" app.plist)
if [[ profileCheck -lt 1 ]]; then
    echo "There is an issue with the provided provisioning profile. For more information see the general notes in the manual which you received from Customer Support together with this tool."
    exit 1;
fi
expiryDate=$(/usr/libexec/PlistBuddy -c "Print ExpirationDate" app.plist | cut -d " " -f 1-3,6 -) 2> /dev/null
expiryFormatted=$(date -jf"%a %b %d %Y" "$expiryDate" +%Y%m%d) 2> /dev/null
todayFormatted=$(date +%Y%m%d) 2> /dev/null

if [[ "$expiryFormatted" -lt "$todayFormatted" ]]; then
    echo "Provisioning profile has expired."
    exit 1;
fi

betaReportCheck=$(/usr/libexec/PlistBuddy -c "Print Entitlements:beta-reports-active" app.plist)
pushCheck=$(/usr/libexec/PlistBuddy -c "Print Entitlements:aps-environment" app.plist)
passCheck=$(grep -c "com.apple.developer.pass-type-identifiers" app.plist)
dataProtectionCheck=$(/usr/libexec/PlistBuddy -c "Print Entitlements:com.apple.developer.default-data-protection" app.plist)
appIdLong=$(/usr/libexec/PlistBuddy -c "Print Entitlements:application-identifier" app.plist)
appIdPrefix=$(echo $appIdLong | cut -d "." -f 1)
reverseUrl=$(echo $appIdLong | cut -d "." -f2- )
finalName=$(echo $reverseUrl | tr "." "_")
teamNameProvisioningProfile=$(/usr/libexec/PlistBuddy -c "Print TeamName" app.plist)
teamIdProvisioningProfile=$(/usr/libexec/PlistBuddy -c "Print TeamIdentifier:0" app.plist)

if [[ ! $teamIdProvisioningProfile ==  $appIdPrefix ]]; then
    echo "Team ID and App ID Prefix do not match."
    exit 1;
fi

echo "Creating entitlements.plist based on existing app"
/usr/bin/codesign -d --entitlements :entitlements.plist Payload/MEA.app &> /dev/null
if [[ ! -e entitlements.plist ]]; then
    echo "File entitlements.plist not created. Run again."
    exit 1;
fi

sleep 1
if [[ $passCheck == 0 ]]
    then
        echo "This provisioning profile does not have Wallet entitlement! This entitlement is required by this app and can be enabled from developer.apple.com. It will require a new provisoining profile after the App ID is updated to include Wallet."
        exit 1;
fi
sleep 1
if [[ "$pushCheck" = "production" ]];
    then
        echo "Push is enabled for use in production on this provisioning profile."
    else
        echo "This provisioning profile doesn't have push entitlement!"
        exit 1;
fi
sleep 1
if [[ "$dataProtectionCheck" = "NSFileProtectionCompleteUntilFirstUserAuthentication" ]];
    then
        echo "NSFileProtectionCompleteUntilFirstUserAuthentication is enabled for use on this provisioning profile."
    else
        echo "This provisioning profile doesn't have file data protection NSFileProtectionCompleteUntilFirstUserAuthentication enabled! This entitlement is required by this app and can be enabled from developer.apple.com. It will require a new provisoining profile after the App ID is updated to include NSFileProtectionCompleteUntilFirstUserAuthentication."
        exit 1;
fi

/usr/libexec/PlistBuddy -c "Set com.apple.developer.team-identifier $teamIdProvisioningProfile" entitlements.plist
/usr/libexec/PlistBuddy -c "Set application-identifier $appIdLong" entitlements.plist
/usr/libexec/PlistBuddy -c "Set com.apple.developer.pass-type-identifiers:0 '$appIdPrefix'.*" entitlements.plist

if [[ "$store" == "true" ]]; then
    if [[ "$betaReportCheck" == "true" ]]; then
        /usr/libexec/PlistBuddy -c "Add beta-reports-active bool true" entitlements.plist
    else
        /usr/libexec/PlistBuddy -c "Delete beta-reports-active" entitlements.plist
    fi
else 
    /usr/libexec/PlistBuddy -c "Delete beta-reports-active" entitlements.plist
fi

cp "$profileFile" Payload/MEA.app/embedded.mobileprovision

/usr/libexec/PlistBuddy -c "Set CFBundleIdentifier $reverseUrl" Payload/MEA.app/Info.plist

certHash=$(cat app.plist \
    | sed -ne 's/^.*<data>\(.*\)<\/data>.*$/\1/p' \
    | base64 -D \
    | shasum \
    | cut -d  " " -f1 \
    | tr '[:lower:]' '[:upper:]')
/usr/bin/security find-identity -v -p codesigning > identity.txt
countOfSigningIdentities=$(cat identity.txt \
    | grep "valid identities found" \
    | cut -d "v" -f1 \
    | tr -d [:blank:])
if [[ ! $countOfSigningIdentities == 0 ]]; then
    echo "You have $countOfSigningIdentities valid signing identities in your Keychain."
else
    echo "A valid Distribution certificate is needed to continue."
    exit 1;
fi

certHashCount=$(grep "$certHash" identity.txt | wc -l | tr -d [:blank:]) 
if ! [[ "$certHashCount" == "0" ]]; then
        echo "Distribution Certificate present for $teamNameProvisioningProfile"
        echo "Codesigning the App"
        codesign -fs "$certHash" Payload/MEA.app/Frameworks/*.framework >/dev/null
        codesign -fs "$certHash" --entitlements entitlements.plist Payload/MEA.app >/dev/null
elif [[ "$certHashCount" == "0" ]]; then
    echo "The correct distribution certificate is not present in Keychain Access. Match the expiry date, which is $expiryDate."
    exit 1;
fi

echo "Validating the signing"
codesign -dvvv Payload/MEA.app &> validation.txt 

cat validation.txt

validationReverseURL=$(grep "Identifier" validation.txt | cut -d "=" -f2 | tr "\n" " " | cut -d " " -f1)
validationTeamDigit=$(grep "TeamIdentifier" validation.txt | cut -d "=" -f2)
entitlementsSigningTeamDigit=$(/usr/libexec/PlistBuddy -c "Print com.apple.developer.team-identifier" entitlements.plist)

sleep 1
if [[ "$reverseUrl" != "$validationReverseURL" ]];
    then
    echo "Reverse URL was not updated successfully."
    exit 1;
fi
sleep 1
if [[ "$validationTeamDigit" != "$teamIdProvisioningProfile" ]];
    then
    echo "Team Identifier is incorrect."
    exit 1;
fi
sleep 1
if [[ "$entitlementsSigningTeamDigit" != "$teamIdProvisioningProfile" ]];
    then
    echo "Team Identifier is incorrect."
    exit 1;
fi

echo "App Signing Validated"
echo "Zipping app, this might take a moment."
mkdir ~/Desktop/SigningTool_Output-$datevar
mv entitlements.plist ~/Desktop/SigningTool_Output-$datevar/entitlements.plist
if [[ "$store" == "true" ]]; then
    zip -rq  ~/Desktop/SigningTool_Output-$datevar/"$finalName"-AppStore.ipa Payload/
else 
    zip -rq  ~/Desktop/SigningTool_Output-$datevar/"$finalName"-Enterprise.ipa Payload/
fi
echo "The finished file is on your Desktop in a folder called SigningTool_Output-$datevar"
open ~/Desktop/SigningTool_Output-$datevar

rm -rf "$app" "$profileFile" app.plist identity.txt validation.txt Payload/
