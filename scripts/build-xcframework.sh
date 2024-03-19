#!/bin/bash
sdks=( iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
destinations=( "generic/platform=iOS" "generic/platform=iOS Simulator" "generic/platform=macOS" "generic/platform=tvOS" "generic/platform=tvOS Simulator" "generic/platform=watchOS" "generic/platform=watchOS Simulator" "name=XR OS" "name=XR Simulator" )

rm -rf Carthage/
mkdir Carthage

ALL_SDKS=$(xcodebuild -showsdks)

generate_xcframework() {
    local scheme="$1"
    local sufix="${2:-}"
    local MACH_O_TYPE="${3-mh_dylib}"
    
    local createxcframework="xcodebuild -create-xcframework "
    
    rm -rf Carthage/DerivedData
    
    
    for i in "${!sdks[@]}"; do
        local sdk="${sdks[i]}"
        local destination="${destinations[i]}"
        if [[ -n "$(grep "${sdk}" <<< "$ALL_SDKS")" ]]; then
            
            echo "---Compiling: Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/Products/Library/Frameworks/${scheme}.framework"
        
            xcodebuild archive -project Sentry.xcodeproj/ -scheme "$scheme" -configuration Release -sdk "$sdk" -destination "$destination" -archivePath ./Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive CODE_SIGNING_REQUIRED=NO SKIP_INSTALL=NO CODE_SIGN_IDENTITY= CARTHAGE=YES MACH_O_TYPE=$MACH_O_TYPE
            
            createxcframework+="-framework Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/Products/Library/Frameworks/${scheme}.framework "
            
            if [ -d "Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/dSYMs/${scheme}.framework.dSYM" ]; then
                # Has debug symbols
                    createxcframework+="-debug-symbols $(pwd -P)/Carthage/archive/${scheme}${sufix}/${sdk}.xcarchive/dSYMs/${scheme}.framework.dSYM "
            fi
        else
            echo "${sdk} SDK not found"
        fi
    done
    
    
    #Create framework for mac catalyst
    xcodebuild -project Sentry.xcodeproj/ -scheme "$scheme" -configuration Release -sdk macosx -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath ./Carthage/DerivedData CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= CARTHAGE=YES MACH_O_TYPE=$MACH_O_TYPE SUPPORTS_MACCATALYST=YES
    
    createxcframework+="-framework Carthage/DerivedData/Build/Products/Release-maccatalyst/${scheme}.framework "
    if [ -d "Carthage/DerivedData/Build/Products/Release-maccatalyst/${scheme}.framework.dSYM" ]; then
        createxcframework+="-debug-symbols $(pwd -P)/Carthage/DerivedData/Build/Products/Release-maccatalyst/${scheme}.framework.dSYM "
    fi
    
    createxcframework+="-output Carthage/${scheme}${sufix}.xcframework"
    echo "---RUNNING: ${createxcframework}"
    $createxcframework
}

generate_xcframework "Sentry" "-Dynamic"

generate_xcframework "Sentry" "" staticlib

generate_xcframework "SentrySwiftUI"
