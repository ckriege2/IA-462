Name:IALAB-REPO
Version:1
Release:1
Summary:IALABS repository information

Group:  IALAB/Base
License:GPL
URL:    https://www.emich.edu
Source0: /root/rpmbuild/SOURCES/IALAB-REPO.tar.gz
BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-buildroot

%description
Deploys repository information for IALABS Repsitory

%prep
%setup -q

%install
mkdir -p "$RPM_BUILD_ROOT"
cp -R * "$RPM_BUILD_ROOT"

%files
%defattr(750, splunk, splunk, 750 )
%attr(644, root, root) /etc/yum.repos.d/ialabs.repo