Name:IALAB-SPK-FWD
Version:1	
Release:1
Summary:IALABS Splunk Forwarder Deployment RPM

Group:	Splunk/Base
License:GPL
URL:	https://www.thinkahead.com	
Source0: /root/rpmbuild/SOURCES/IALAB-SPK-FWD.tar.gz	
BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-buildroot
Requires:splunkforwarder

%description
Deploys base configuration for an IALABS Splunk server.

%prep
%setup -q

%install
mkdir -p "$RPM_BUILD_ROOT"
cp -R * "$RPM_BUILD_ROOT"

%files
%defattr(750, splunk, splunk, 750 )
%attr(644, root, root) /etc/systemd/system/splunkfwd.service
/opt/splunkforwarder/etc/apps/IALAB-SPK-FWD
/opt/splunkforwarder/etc/log-local.cfg

%post
/usr/bin/systemctl daemon-reload
/usr/bin/systemctl enable splunkfwd.service
/usr/bin/systemctl start splunkfwd.service
%changelog

