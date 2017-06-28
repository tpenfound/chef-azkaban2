name 						 'azkaban3'
maintainer       "Yieldbot"
maintainer_email "hstrong@yieldbot.com"
license          "All rights reserved"
description      "Installs Azkaban"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "3.2.5"

depends 'java'
depends 'mysql', '~> 8.4.0'
