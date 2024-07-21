# 構築手順書:VagrantでWordPressの構築をする
vagrant上にCentOS7・nginxのインストールし、WordPressのインストール手順から記述。


## macOSからVirtualBoxのCentOSに公開鍵認証でssh接続
クライアント側で、/Users/user/.ssh/直下に秘密鍵と公開鍵を作成する
```
$ ssh-keygen -t rsa
```

サーバー側でmentaユーザーを作成し、作成したユーザーにパスワードを設定
```
$ useradd menta
```

サーバー側でsshd_configを編集
```
$ vi sshd_config
```

"PubkeyAuthentication"パラメーター、"PasswordAuthentication"パラメータのコメントアウトを外す
```
PubkeyAuthentication yes
PasswordAuthentication yes
```

変更した設定を反映するためにsshdを再起動
```
$ systemctl restart sshd
```

再起動後にstatusを確認
```
$ systemctl status sshd
```

クライアント側で公開鍵をサーバー側にコピーする
```
$ scp -i 公開鍵 公開鍵のパス menta@192.168.56.15:home/menta/.ssh/authorized_keys
```

クライアント側でssh鍵認証を行う
```
$ ssh -i 秘密鍵 menta@192.168.56.15
```

## WordPressの構築
nginxの設定

```
$ vim /etc/nginx/conf.d/default.conf
```
以下のように編集する
```
server {
    listen       80;
    server_name  localhost;
    root /var/www/html/;
    charset UTF-8;
    access_log  /var/log/nginx/sample.com.access.log  main;
    error_log /var/log/nginx/sample.com.error.log;
    location / {
        index  index.php index.html index.htm;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
    location ~ \.php$ {
        fastcgi_pass   unix:/var/run/php-fpm/php-fpm.sock;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
        include        fastcgi_params;
    }
}
```

nginxの再起動
```
$ systemctl restart nginx
```

phpとphp-fpmのインストール
```
$ yum -y install --enablerepo=epel,remi,remi-php72  php php-mbstring php-pdo php-mysqlnd php-fpm
```

PHPのバージョン確認
```
$ vim /etc/php-fpm.d/www.conf
```

php-confの設定を行う
```
$ vim /etc/php-fpm.d/www.conf
```

それぞれの行を修正する
```
修正前
listen = 127.0.0.1:9000
修正後
listen = /var/run/php-fpm/php-fpm.sock
修正前
user = apache 
修正後
user = nginx 
修正前
group = apache
修正後
group = nginx
修正前
;listen.owner = nobody
;listen.group = nobody
修正後
listen.owner = nginx
listen.group = nginx
```

php-fpmの起動
```
$ systemctl start php-fpm
```

php-fpmの状態確認
```
$ systemctl status php-fpm
```

サーバ再起動時にphp-fpmが自動起動するように設定するようにする
```
$ systemctl enable php-fpm
```

wordpressのインストール
```
$ cd /var/www/html/
```

日本語版の最新のwordpressを取得する
```
$ wget https://ja.wordpress.org/latest-ja.tar.gz
```

解凍する
```
$ tar xfz latest-ja.tar.gz
```

wordpressディレクトリの所有権を変更する
```
$ chown -R nginx. wordpress
```

wordpressをリネイム(とりあえず、sample.comにする)
```
$ mv wordpress sample.com
```

rootの位置をsample.comにする
nginxの設定を修正する
```
$ vim /etc/nginx/conf.d/default.conf
```

rootの行を修正する
```
server {
    listen       80;
    server_name  localhost;
    root /var/www/html/sample.com;
    charset UTF-8;
    省略...
```

設定を変更したのでnginxの再起動
```
$ systemctl restart nginx
```

## CentOS7にMySQL8.0をインストール
rpmコマンドを利用してリポジトリをインストール
```
$ rpm -ivh https://dev.mysql.com/get/mysql80-community-release-el7-2.noarch.rpm
```

mysql-community-serverをインストール
```
$ yum install mysql-community-server
```

mysqld.serviceを起動する
```
$ systemctl start mysqld.service
```

mysqld.serviceを永続化する
```
$ systemctl enable mysqld.service
```

インストール時のrootのパスワードが記述されたログをgrepして確認する。
```
$ grep password /var/log/mysqld.log
```

mysql_secure_installationコマンドを実行
```
$ mysql_secure_installation
```

wordpress用のデータベースを作成する
```
$ mysqladmin -uroot create wordpress
```

MySQLへログイン
```
$ mysql -uroot
```

mentaユーザーを作成
```
GRANT ALL PRIVILEGES ON wordpress .* TO menta@localhost IDENTIFIED BY 'パスワード';
```

ユーザー権限を変更
```
$ chown -R nginx:nginx /var/www/html/sample.com
```

nginxを再起動
```
$ systemctl restart nginx
```

php-fpmを再起動
```
$ systemctl restart php-fpm
```

## WordPressの初期設定

WordPressにログインした後、wp-config.phpを作成し初期設定を行う
```
$ vim /var/www/html/sample.com/wp-config.php
```

ワードプレスの設定画面にある記述をコピペし、
以下の内容を修正
```
define('DB_NAME', 'wordpress');
define('DB_USER', 'XXXXXX');
define('DB_PASSWORD', 'パスワード');
define('DB_HOST', 'localhost');
```

ログインし初期設定が完了したことを確認


## php-fpmをチューニング
www.confを変更
```
$ vim /etc/php-fpm.d/www.conf
```

以下のように修正
```
pm = static
pm.max_children = 10
pm.start_servers = 10
pm.min_spare_servers = 10
pm.max_spare_servers = 10
pm.process_idle_timeout = 10s;
pm.max_requests = 100
php_admin_value[memory_limit] = 256M
```

再起動を行う
```
$ /etc/init.d/php-fpm restart
```


## http://dev.menta.me でアクセスできるよう名前解決
クライアント側のhostsファイルを編集する
```
$ sudo vi /etc/hosts
```

192.168.56.15 と http://dev.menta.me を紐づけるように記述を追加し、hostsファイルの内容を書き換えて上書き保存
```
192.168.56.15 dev.menta.me