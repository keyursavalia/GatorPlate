#!/bin/sh
# Xcode Run Script phase: copies the environment's GoogleService-Info.plist
# (GatorPlate/Config/Firebase/$GATORPLATE_ENV/) into the app bundle. Fails the build when the file is missing,
# registered for another bundle ID or from another Firebase project than GATORPLATE_FIREBASE_PROJECT_ID, so a build can
# never talk to the wrong project. The plists are gitignored; download them from each project's console.
#
# Phase input file:  $(SRCROOT)/GatorPlate/Config/Firebase/$(GATORPLATE_ENV)/GoogleService-Info.plist
# Phase output file: $(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist
set -eu

if [ -z "${GATORPLATE_ENV:-}" ]; then
  echo "error: GATORPLATE_ENV is not set. Assign GatorPlate/Config/Dev.xcconfig (Debug) and GatorPlate/Config/Prod.xcconfig (Release) as the target's base configurations."
  exit 1
fi

SOURCE="${SRCROOT}/GatorPlate/Config/Firebase/${GATORPLATE_ENV}/GoogleService-Info.plist"
DESTINATION="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"

if [ -z "${GATORPLATE_FIREBASE_PROJECT_ID:-}" ]; then
  echo "error: GATORPLATE_FIREBASE_PROJECT_ID is empty in GatorPlate/Config/${GATORPLATE_ENV}.xcconfig. Set it to the ${GATORPLATE_ENV} Firebase project ID."
  exit 1
fi

if [ ! -f "${SOURCE}" ]; then
  echo "error: Missing ${SOURCE}. Download GoogleService-Info.plist for ${PRODUCT_BUNDLE_IDENTIFIER} from the ${GATORPLATE_ENV} Firebase project."
  exit 1
fi

PLIST_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "${SOURCE}")
if [ "${PLIST_BUNDLE_ID}" != "${PRODUCT_BUNDLE_IDENTIFIER}" ]; then
  echo "error: ${SOURCE} is for ${PLIST_BUNDLE_ID}, but this build is ${PRODUCT_BUNDLE_IDENTIFIER}."
  exit 1
fi

PLIST_PROJECT_ID=$(/usr/libexec/PlistBuddy -c "Print :PROJECT_ID" "${SOURCE}")
if [ "${PLIST_PROJECT_ID}" != "${GATORPLATE_FIREBASE_PROJECT_ID}" ]; then
  echo "error: ${SOURCE} belongs to Firebase project ${PLIST_PROJECT_ID}, expected ${GATORPLATE_FIREBASE_PROJECT_ID}."
  exit 1
fi

cp "${SOURCE}" "${DESTINATION}"
echo "Firebase config: ${GATORPLATE_ENV} (${PLIST_PROJECT_ID})"
