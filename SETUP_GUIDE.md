# OrderDesk — Configured for `order-desk-wapp` (Free Spark Plan)

നിങ്ങളുടെ Firebase Web & Android (`com.wapp.orderdesk`) കോൺഫിഗറേഷൻ ഈ പ്രോജക്റ്റിൽ ഇതിനകം ചേർത്തിട്ടുണ്ട്.

## ഇനി ചെയ്യേണ്ടത് (3 ലളിതമായ സ്റ്റെപ്പുകൾ)
1. **Firebase Console (`order-desk-wapp`) പരിശോധിക്കുക:**
   - **Authentication → Email/Password** ഓൺ ആക്കി, *Users* ടാബിൽ നിങ്ങളുടെ Shared Login Email & Password ആഡ് ചെയ്യുക.
   - **Firestore Database** (asia-south1 Mumbai) ക്രിയേറ്റ് ചെയ്ത്, ഈ പ്രോജക്റ്റിലെ `firestore.rules` പേസ്റ്റ് ചെയ്ത് Publish ചെയ്യുക.
2. **GitHub-ലേക്ക് Push ചെയ്യുക:**
   - ഈ ഫോൾഡർ നിങ്ങളുടെ GitHub repo-യിലേക്ക് push ചെയ്താലുടൻ **Actions → Build Universal APK & Web** തനിയെ റൺ ആകും.
   - പൂർത്തിയാകുമ്പോൾ **Artifacts**-ൽ നിന്ന് `orderdesk-universal-apk` (Android App) ഡൗൺലോഡ് ചെയ്ത് ഇൻസ്റ്റാൾ ചെയ്യാം, `orderdesk-web-build` എടുത്ത് Vercel അല്ലെങ്കിൽ Firebase Hosting-ൽ (`firebase deploy --only hosting`) വെബ്സൈറ്റായി ഹോസ്റ്റ് ചെയ്യാം.
3. **ആദ്യ ലോഗിൻ:**
   - ലോഗിൻ ചെയ്ത ശേഷം **Settings → Load Lakfa Defaults** അമർത്തുക. എല്ലാ Lakfa Foods പ്രോഡക്റ്റുകളും 9 WhatsApp ടെംപ്ലേറ്റുകളും ഉടൻ ലോഡ് ആകും.
