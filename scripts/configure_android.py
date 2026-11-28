#!/usr/bin/env python3
import base64
import os
import shutil
import subprocess
from pathlib import Path


def main() -> None:
    gs_src = Path("firebase/google-services.json")
    if gs_src.exists():
        shutil.copy2(gs_src, Path("android/app/google-services.json"))

    xml_dir = Path("android/app/src/main/res/xml")
    xml_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(Path("android_config/file_paths.xml"), xml_dir / "file_paths.xml")

    kotlin_dir = Path("android/app/src/main/kotlin/com/wapp/orderdesk")
    kotlin_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(Path("android_config/MainActivity.kt"), kotlin_dir / "MainActivity.kt")

    signing_dir = Path.home() / ".android-signing"
    signing_dir.mkdir(parents=True, exist_ok=True)
    keystore_dest = Path("android/app/release-keystore.jks")

    keystore_b64 = os.environ.get("ANDROID_KEYSTORE_BASE64", "").strip()
    if keystore_b64:
        keystore_dest.write_bytes(base64.b64decode(keystore_b64))
        store_pass = os.environ.get("ANDROID_STORE_PASSWORD") or "orderdesk2026"
        key_alias = os.environ.get("ANDROID_KEY_ALIAS") or "orderdesk"
        key_pass = os.environ.get("ANDROID_KEY_PASSWORD") or store_pass
    else:
        cached_jks = signing_dir / "orderdesk-release.jks"
        if not cached_jks.exists():
            subprocess.run(
                [
                    "keytool",
                    "-genkey",
                    "-v",
                    "-keystore",
                    str(cached_jks),
                    "-storepass",
                    "orderdesk2026",
                    "-alias",
                    "orderdesk",
                    "-keypass",
                    "orderdesk2026",
                    "-keyalg",
                    "RSA",
                    "-keysize",
                    "2048",
                    "-validity",
                    "10000",
                    "-dname",
                    "CN=OrderDesk, O=OrderDesk, C=IN",
                ],
                check=True,
            )
        shutil.copy2(cached_jks, keystore_dest)
        store_pass = "orderdesk2026"
        key_alias = "orderdesk"
        key_pass = "orderdesk2026"

    Path("android/key.properties").write_text(
        f"storePassword={store_pass}\n"
        f"keyPassword={key_pass}\n"
        f"keyAlias={key_alias}\n"
        "storeFile=release-keystore.jks\n"
    )

    manifest_path = Path("android/app/src/main/AndroidManifest.xml")
    if manifest_path.exists():
        m = manifest_path.read_text()
        if "android.permission.INTERNET" not in m:
            m = m.replace(
                "<application",
                '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
                1,
            )
        if "android.permission.REQUEST_INSTALL_PACKAGES" not in m:
            m = m.replace(
                "<application",
                '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>\n    <application',
                1,
            )
        if "android:allowBackup" not in m:
            m = m.replace("<application", '<application android:allowBackup="false"', 1)
        if "androidx.core.content.FileProvider" not in m:
            provider = (
                '        <provider\n'
                '            android:name="androidx.core.content.FileProvider"\n'
                '            android:authorities="${applicationId}.fileprovider"\n'
                '            android:exported="false"\n'
                '            android:grantUriPermissions="true">\n'
                '            <meta-data\n'
                '                android:name="android.support.FILE_PROVIDER_PATHS"\n'
                '                android:resource="@xml/file_paths" />\n'
                '        </provider>\n'
                '    </application>'
            )
            m = m.replace("</application>", provider, 1)
        manifest_path.write_text(m)

    kts_path = Path("android/app/build.gradle.kts")
    groovy_path = Path("android/app/build.gradle")
    if kts_path.exists():
        g = kts_path.read_text()
        if "key.properties" not in g:
            header = (
                "import java.util.Properties\n"
                "import java.io.FileInputStream\n\n"
                "val keystoreProperties = Properties()\n"
                'val keystorePropertiesFile = rootProject.file("key.properties")\n'
                "if (keystorePropertiesFile.exists()) {\n"
                "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
                "}\n\n"
            )
            g = header + g
        if 'create("release")' not in g:
            signing_cfg = (
                "    signingConfigs {\n"
                '        create("release") {\n'
                '            keyAlias = keystoreProperties.getProperty("keyAlias")\n'
                '            keyPassword = keystoreProperties.getProperty("keyPassword")\n'
                '            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }\n'
                '            storePassword = keystoreProperties.getProperty("storePassword")\n'
                "        }\n"
                "    }\n\n"
                "    buildTypes {"
            )
            if "buildTypes {" in g:
                g = g.replace("buildTypes {", signing_cfg, 1)
            else:
                g = g + "\nandroid {\n" + signing_cfg.replace("    buildTypes {", "") + "}\n"
        g = g.replace(
            'signingConfig = signingConfigs.getByName("debug")',
            'signingConfig = signingConfigs.getByName("release")',
        )
        if "checkReleaseBuilds" not in g:
            g = g + (
                "\nandroid {\n"
                "    lint {\n"
                "        checkReleaseBuilds = false\n"
                "        abortOnError = false\n"
                "    }\n"
                "}\n"
            )
        kts_path.write_text(g)
    elif groovy_path.exists():
        g = groovy_path.read_text()
        if "key.properties" not in g:
            header = (
                "def keystoreProperties = new Properties()\n"
                "def keystorePropertiesFile = rootProject.file('key.properties')\n"
                "if (keystorePropertiesFile.exists()) {\n"
                "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
                "}\n\n"
            )
            g = header + g
        if "signingConfigs" not in g or "release {" not in g:
            signing_cfg = (
                "    signingConfigs {\n"
                "        release {\n"
                "            keyAlias keystoreProperties['keyAlias']\n"
                "            keyPassword keystoreProperties['keyPassword']\n"
                "            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null\n"
                "            storePassword keystoreProperties['storePassword']\n"
                "        }\n"
                "    }\n\n"
                "    buildTypes {"
            )
            if "buildTypes {" in g:
                g = g.replace("buildTypes {", signing_cfg, 1)
            else:
                g = g + "\nandroid {\n" + signing_cfg.replace("    buildTypes {", "") + "}\n"
        g = g.replace(
            "signingConfig signingConfigs.debug",
            "signingConfig signingConfigs.release",
        )
        if "checkReleaseBuilds" not in g:
            g = g + (
                "\nandroid {\n"
                "    lintOptions {\n"
                "        checkReleaseBuilds false\n"
                "        abortOnError false\n"
                "    }\n"
                "}\n"
            )
        groovy_path.write_text(g)


if __name__ == "__main__":
    main()
