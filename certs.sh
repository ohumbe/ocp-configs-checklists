cat > csr.cnf <<EOF 
#conf                                                              
[req]
distinguished_name = req_distinguished_name
req_extensions = req_ext
prompt = no
[req_distinguished_name]
C   = US
ST  = California
L   = Livermore
O   = LLNL
OU  = POC
CN  = localhost
[req_ext]
subjectAltName = @alt_names
[alt_names]

EOF

#cert CA
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.pem -config csr.cnf




cat > ssl.cnf <<EOF 

[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
DNS.2 = quay-server
IP.1 = 192.168.122.25

EOF


#csr and key

openssl req -newkey rsa:2048 -keyout ocpmgm01.key -out ocpmgm01.csr -config csr.cnf

#verify                                   
openssl req -noout -text -in ocpmgm01.csr  


#make unpassword protected key

openssl rsa -in localhost.key -out key.unencrypted.pem 

#certs 




openssl x509 -req -in ocpmgm01.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out ssl.cert   -days 356 -extensions v3_req -extfile ssl.cnf  

#verify
 openssl x509 -noout -text -in ssl.cert 


