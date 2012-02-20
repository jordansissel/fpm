%define __jar_repack 0

Name: test_data
Version: 1.0
Release: 1
Summary: no description given
BuildArch: noarch
AutoReqProv: no

Group: default
License: unknown
URL: http://nourlgiven.example.com/no/url/given
Source0:  %{_sourcedir}/data.tar.gz
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

%description
no description given

%prep
# noop

%build
# noop

%install
# some rpm implementations delete the build dir and then recreate it by
# default, for some reason. Whatever, let's work around it.
cd $RPM_BUILD_ROOT
tar -zxf %SOURCE0

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)

/test_data/dir/

%changelog
