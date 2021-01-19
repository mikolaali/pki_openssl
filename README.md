Задача поднять инфраструктуру для одного сервера
Скрипт должен обладать следующим функционалом
1. Создание pki для одного сервера с database и crl с возможностью определить home dir
2. возможность создать множество клиентов из файла + готовый конфиг со всеми ключами и сертификатом
3. возможность создать одного клиента
4. возможность отозвать сертификат

# 1.create pki: 
   random_file 
   a. ca.key|cert   
   b. dh.pem 
   c. server.key|cert
   d. ta.key
   e. server.conf
   f. client.key|cert
   g. clinet.conf from file or array
   h. openssl ca -gencrl crl.pem 
   i. mkdir ccd
# 2.

Ветвление , возможные варианты использования
1) pki create , пункты a,b,c,d
   /etc/openvpn/server/keys
   /etc/openvpn/server/crl 
   /etc/openvpn/server/ccd 
   /etc/openvpn/server/configs
   ca.key|cert dh.pem server.key|cert ta.key
   server.conf 
2) client.cert|key  client.conf
3) crl.pem fake.crt -> revoke
