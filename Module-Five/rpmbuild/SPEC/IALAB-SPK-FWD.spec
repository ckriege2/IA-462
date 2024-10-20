Name:IA462-SPK-FWD
Version:1	
Release:1
Summary:IA462 Splunk Forwarder Deployment RPM

Group:	Splunk/Base
License:GPL
URL:	https://www.emich.edu
Source0: /root/rpmbuild/SOURCES/IA462-SPK-FWD.tar.gz	
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
/opt/splunkforwarder/etc/apps/spk-uf-deploy

%post
/opt/splunkforwarder/bin/splunk enable boot-start -systemd-managed 1 -user splunkfwd -group splunkfwd
/usr/bin/systemctl daemon-reload
/usr/bin/systemctl enable splunkfwd
/usr/bin/systemctl start splunkfwd
%changelog

