%global _hardened_build 1
%global _prefix         /usr/local/lokahost/php

Name:           lokahost-php
Version:        8.2.8
Release:        1%{dist}
Summary:        Lokahost internal PHP
Group:          System Environment/Base
URL:            https://www.lokahost.com
Source0:        https://www.php.net/distributions/php-%{version}.tar.gz
Source1:        lokahost-php.service
Source2:        php-fpm.conf
Source3:        php.ini
License:        PHP and Zend and BSD and MIT and ASL 1.0 and NCSA
Vendor:         lokahost.com
Requires:       redhat-release >= 8
Provides:       lokahost-php = %{version}
BuildRequires:  autoconf, automake, bison, bzip2-devel, gcc, gcc-c++, gnupg2, libtool, make, openssl-devel, re2c
BuildRequires:  gmp-devel, oniguruma-devel, libzip-devel
BuildRequires:  pkgconfig(libcurl)  >= 7.61.0
BuildRequires:  pkgconfig(libxml-2.0)  >= 2.9.7
BuildRequires:  pkgconfig(sqlite3) >= 3.26.0
BuildRequires:  systemd

%description
This package contains internal PHP for Lokahost Control Panel web interface.

%prep
%autosetup -p1 -n php-%{version}

# https://bugs.php.net/63362 - Not needed but installed headers.
# Drop some Windows specific headers to avoid installation,
# before build to ensure they are really not needed.
rm -f TSRM/tsrm_win32.h \
      TSRM/tsrm_config.w32.h \
      Zend/zend_config.w32.h \
      ext/mysqlnd/config-win.h \
      ext/standard/winver.h \
      main/win32_internal_function_disabled.h \
      main/win95nt.h

%build
%if 0%{?rhel} > 8
# This package fails to build with LTO due to undefined symbols.  LTO
# was disabled in OpenSuSE as well, but with no real explanation why
# beyond the undefined symbols.  It really should be investigated further.
# Disable LTO
%define _lto_cflags %{nil}
%endif
%configure --sysconfdir=%{_prefix}%{_sysconfdir} \
		--with-libdir=lib/$(arch)-linux-gnu \
		--enable-fpm --with-fpm-user=admin --with-fpm-group=admin \
		--with-openssl \
		--with-mysqli \
		--with-gettext \
		--with-curl \
		--with-zip \
		--with-gmp \
		--enable-mbstring
%make_build

%install
%{__rm} -rf $RPM_BUILD_ROOT
mkdir -p %{buildroot}%{_unitdir} %{buildroot}/usr/local/lokahost/php/{etc,lib}
%make_install INSTALL_ROOT=$RPM_BUILD_ROOT/usr/local/lokahost/php
%{__install} -m644 %{SOURCE1} %{buildroot}%{_unitdir}/lokahost-php.service
cp %{SOURCE2} %{buildroot}/usr/local/lokahost/php/etc/
cp %{SOURCE3} %{buildroot}/usr/local/lokahost/php/lib/

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%pre

%post
%systemd_post lokahost-php.service

%preun
%systemd_preun lokahost-php.service

%postun
%systemd_postun_with_restart lokahost-php.service

%files
%defattr(-,root,root)
%attr(755,root,root) /usr/local/lokahost/php
%attr(775,admin,admin) /usr/local/lokahost/php/var/log
%attr(775,admin,admin) /usr/local/lokahost/php/var/run
%config(noreplace) /usr/local/lokahost/php/etc/php-fpm.conf
%config(noreplace) /usr/local/lokahost/php/lib/php.ini
%{_unitdir}/lokahost-php.service

%changelog
* Sun May 14 2023 Istiak Ferdous <hello@istiak.com> - 8.2.6-1
- LokahostCP RHEL 9 support

* Thu Jun 25 2020 Ernesto Nicolás Carrea <equistango@gmail.com> - 7.4.6
- LokahostCP CentOS 8 support
