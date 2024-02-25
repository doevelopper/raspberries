
# TLS this program!

As you may note, what is in here is exactly what you got for the review exercies

The reason is simple, your task here is to make the client and server here speak
TLS!

# Exercise 1a:

For a first step Make the client connect anonymously, and validate the server's certificate.

- Use the root certificate from ../CA/root.pem as the root of trust
- Use the server certificate from ../CA/server.[key|crt] as the server certificate

Stop at the point that you get the client talking to the server. Other exercises below
will build upon this.

# Exercise 1b

As a follow on to 1a, modify your program (or my solution) so the server insists on client
verification, and the client provides the certificate from ../CA/client.[crt|key]

Try using both optional, and required client validation.

Now modify the client and the server to print out details of each other's certificate
after the handshake - Make use of the function in report_tls.c if you like, and add
it to your code. 

# Exercise 1r

### CRL use
For certificate verification, modify your program so that the client supports a CRL list.

The CRL for your certificates is located in ../CA/intermediate/crl/intermediate.crl.pem.

Start your server up using ../CA/revoked.[key|crt] instead of server.crt. Try to connect to it when using the CRL and not using the CRL.

### OCSP Stapling

Modify your server to use an OCSP staple file. Set your server up to use server.crt, then you can fetch an ocsp staple for server.crt by first:

- running the ocsp server in ../CA/ocspserver.sh, and then
- connecting to it using ../CA/ocspfetch.sh server.crt

This which will retreive a server.crt-ocsp.der file. The der file can be used as the input file for a call to [tls_config_set_ocsp_staple_file](http://man.openbsd.org/tls_config_set_ocsp_staple_file.3) in your server code. 

Modify your client to check for the OCSP staple and show it, or to require it. - connect up and see what happens.

If you have time you can try the same thing with the revoked certificate in the server.







