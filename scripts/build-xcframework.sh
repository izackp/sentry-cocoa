#!/bin/bash

set -eou pipefail
sdks=( iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
destinations=( "generic/platform=iOS" "generic/platform=iOS Simulator" "generic/platform=macOS" "generic/platform=tvOS" "generic/platform=tvOS Simulator" "generic/platform=watchOS" "generic/platform=watchOS Simulator" "name=XR OS" "name=XR Simulator" )

rm -rf Carthage/
mkdir Carthage

ALL_SDKS=$(xcodebuild -showsdks)

generate_xcframework() {
    local scheme="$1"
    local sufix="${2:-}"
    local MACH_O_TYPE="${3-mh_dylib}"
    local configuration="${4-Release}"
    local createxcframework="xcodebuild -create-xcframework "
    local GCC_GENERATE_DEBUGGING_SYMBOLS="YES"
    
    if [ "$MACH_O_TYPE" = "staticlib" ]; then
        #For static framework we disabled symbols because they are not distributed in the framework causing warnings.
        GCC_GENERATE_DEBUGGING_SYMBOLS="NO"
    fi
    
    rm -rf Carthage/DerivedData
    
    
    for i in "${!sdks[@]}"; do
        local sdk="${sdks[i]}"
        local destination="${destinations[i]}"
        if [[ -n "$(grep "${sdk}" <<< "$ALL_SDKS")" ]]; then

            echo "---Compiling: Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/Products/Library/Frameworks/${scheme}.framework"

            xcodebuild archive -project Sentry.xcodeproj/ -scheme "$scheme" -configuration "$configuration" -sdk "$sdk" -destination "$destination" -archivePath ./Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive CODE_SIGNING_REQUIRED=NO SKIP_INSTALL=NO CODE_SIGN_IDENTITY= CARTHAGE=YES MACH_O_TYPE=$MACH_O_TYPE ENABLE_CODE_COVERAGE=NO GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS"

            createxcframework+="-framework Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/Products/Library/Frameworks/${scheme}.framework "

            if [ "$MACH_O_TYPE" = "staticlib" ]; then
                local infoPlist="Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/Products/Library/Frameworks/${scheme}.framework/Info.plist"
                
                if [ ! -e "$infoPlist" ]; then
                    infoPlist="Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/Products/Library/Frameworks/${scheme}.framework/Resources/Info.plist"
                fi
                # This workaround is necessary to make Sentry Static framework to work
                #More information in here: https://github.com/getsentry/sentry-cocoa/issues/3769
                plutil -replace "MinimumOSVersion" -string "9999" "$infoPlist"
            fi
            
            if [ -d "Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/dSYMs/${scheme}.framework.dSYM" ]; then
                # Has debug symbols
                    createxcframework+="-debug-symbols $(pwd -P)/Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/dSYMs/${scheme}.framework.dSYM "
            fi
        else
            echo "${sdk} SDK not found"
        fi
    done
    
    
    #Create framework for mac catalyst
    xcodebuild -project Sentry.xcodeproj/ -scheme "$scheme" -configuration "$configuration" -sdk iphoneos -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath ./Carthage/DerivedData CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= CARTHAGE=YES MACH_O_TYPE=$MACH_O_TYPE SUPPORTS_MACCATALYST=YES ENABLE_CODE_COVERAGE=NO GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS"

    if [ "$MACH_O_TYPE" = "staticlib" ]; then
        local infoPlist="Carthage/DerivedData/Build/Products/"$configuration"-maccatalyst/${scheme}.framework/Resources/Info.plist"
        plutil -replace "MinimumOSVersion" -string "9999" "$infoPlist"
    fi
    
    createxcframework+="-framework Carthage/DerivedData/Build/Products/"$configuration"-maccatalyst/${scheme}.framework "
    if [ -d "Carthage/DerivedData/Build/Products/"$configuration"-maccatalyst/${scheme}.framework.dSYM" ]; then
        createxcframework+="-debug-symbols $(pwd -P)/Carthage/DerivedData/Build/Products/"$configuration"-maccatalyst/${scheme}.framework.dSYM "
    fi
    
    createxcframework+="-output Carthage/${scheme}${sufix}.xcframework"
    echo "---RUNNING: ${createxcframework}"
    $createxcframework
}

generate_xcframework "Sentry" "-Dynamic"

generate_xcframework "Sentry" "" staticlib

generate_xcframework "SentrySwiftUI"

generate_xcframework "Sentry" "-WihoutUIKitOrAppKit" mh_dylib Release_without_UIKit
