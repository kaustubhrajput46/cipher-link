@echo off
REM Windows batch script to generate local PKI for Cipher-Link
REM Uses OpenSSL installed at C:\Program Files\OpenSSL-Win64

setlocal enabledelayedexpansion

set OPENSSL="C:\Program Files\OpenSSL-Win64\bin\openssl.exe"

echo ========================================
echo Cipher-Link PKI Generation Script
echo ========================================
echo OpenSSL Version:
%OPENSSL% version
echo.

REM Output directory
set OUTDIR=local-pki
if exist %OUTDIR% (
    echo Removing existing PKI directory...
    rmdir /s /q %OUTDIR%
)
mkdir %OUTDIR%
cd %OUTDIR%

echo.
echo [1/10] Generating CA private key (4096-bit RSA)...
%OPENSSL% genpkey -algorithm RSA -out rootCA.key -pkeyopt rsa_keygen_bits:4096
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to generate CA key
    pause
    exit /b 1
)

echo [2/10] Creating self-signed root CA certificate...
%OPENSSL% req -x509 -new -nodes -key rootCA.key -sha256 -days 3650 -subj "/CN=Local Test Root CA/O=CipherLink/OU=Security" -out rootCA.pem
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to create CA certificate
    pause
    exit /b 1
)

echo [3/10] Generating server private key (2048-bit RSA)...
%OPENSSL% genpkey -algorithm RSA -out server.key -pkeyopt rsa_keygen_bits:2048

echo [4/10] Creating server certificate signing request...
%OPENSSL% req -new -key server.key -subj "/CN=localhost/O=CipherLink/OU=Server" -out server.csr

echo [5/10] Creating server certificate extensions...
(
echo basicConstraints=CA:FALSE
echo subjectAltName = DNS:localhost,DNS:example.local,IP:127.0.0.1
echo keyUsage = digitalSignature, keyEncipherment
echo extendedKeyUsage = serverAuth
) > server_ext.cnf

echo [6/10] Signing server certificate with CA...
%OPENSSL% x509 -req -in server.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out server.crt -days 825 -sha256 -extfile server_ext.cnf

echo [7/10] Generating client private key (2048-bit RSA)...
%OPENSSL% genpkey -algorithm RSA -out client.key -pkeyopt rsa_keygen_bits:2048

echo [8/10] Creating client certificate signing request...
%OPENSSL% req -new -key client.key -subj "/CN=cipher-link-client/O=CipherLink/OU=Client" -out client.csr

echo [9/10] Creating client certificate extensions...
(
echo basicConstraints=CA:FALSE
echo keyUsage = digitalSignature, keyEncipherment
echo extendedKeyUsage = clientAuth
) > client_ext.cnf

echo [10/10] Signing client certificate with CA...
%OPENSSL% x509 -req -in client.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out client.crt -days 825 -sha256 -extfile client_ext.cnf

echo.
echo ========================================
echo Creating PKCS#12 Keystores and Truststores
echo ========================================
echo.

REM Set passwords
set SERVER_PASSWORD=serverpass
set CLIENT_PASSWORD=clientpass
set TRUSTSTORE_PASSWORD=trustpass

echo Creating server keystore (PKCS#12)...
%OPENSSL% pkcs12 -export -inkey server.key -in server.crt -certfile rootCA.pem -out server-keystore.p12 -name server -password pass:%SERVER_PASSWORD%

echo Creating client keystore (PKCS#12)...
%OPENSSL% pkcs12 -export -inkey client.key -in client.crt -certfile rootCA.pem -out client-keystore.p12 -name client -password pass:%CLIENT_PASSWORD%

echo Creating truststore with root CA (PKCS#12)...
keytool -import -noprompt -trustcacerts -alias localroot -file rootCA.pem -keystore truststore.p12 -storetype PKCS12 -storepass %TRUSTSTORE_PASSWORD%

echo Creating server-side truststore for client cert validation...
copy truststore.p12 server-truststore.p12 >nul

echo.
echo Creating revocation list file...
(
echo #revoked_serials
echo # Format: one serial number per line ^(hex, case-insensitive^)
echo # Add certificate serial numbers below to revoke them
echo # Example: a1b2c3d4e5f6
) > revoked.txt

echo.
echo Saving password information...
(
echo SERVER_KEYSTORE=server-keystore.p12
echo SERVER_KEY_PASS=%SERVER_PASSWORD%
echo CLIENT_KEYSTORE=client-keystore.p12
echo CLIENT_KEY_PASS=%CLIENT_PASSWORD%
echo TRUSTSTORE=truststore.p12
echo TRUSTSTORE_PASS=%TRUSTSTORE_PASSWORD%
) > passwords.txt

echo.
echo ========================================
echo PKI Generation Complete!
echo ========================================
echo.
echo Generated files in %cd%:
echo   - rootCA.pem              (Root CA certificate)
echo   - server-keystore.p12     (Server certificate + private key)
echo   - client-keystore.p12     (Client certificate + private key)
echo   - truststore.p12          (Trusted CA certificates)
echo   - server-truststore.p12   (Server-side truststore)
echo   - revoked.txt             (Certificate revocation list)
echo   - passwords.txt           (Keystore passwords - DO NOT COMMIT!)
echo.
echo Server certificate info:
%OPENSSL% x509 -in server.crt -noout -subject -issuer -dates -serial
echo.
echo Client certificate info:
%OPENSSL% x509 -in client.crt -noout -subject -issuer -dates -serial
echo.
echo Next steps:
echo   1. Copy local-pki folder to src/main/resources/
echo   2. Build the project: mvn clean package
echo   3. Run the server: java -jar target/cipher-link-0.0.1-SNAPSHOT.jar
echo.

cd ..
endlocal
pause

