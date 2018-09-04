# zfm-archive-uploader
Upload 24/7/365 audio log to Archive.org for ZFM Zandvoort

This tool is used by ZFM Zandvoort to upload all broadcasted hours to [Archive.org][1]. The files are uploaded using the FTP upload server of [Archive.org][1], which is the somewhat slower method, but was easy to implement.

The files uploaded are later released by our archive maintainer, who humorously dubbed this script the 'MSS (Marcus's Script Service)'. For an example upload see <https://archive.org/details/ZFM-2018-08-31>.

You might need to adjust the code to suit your needs, or it may be used as an example.

## Requirements

This script should run on Linux as well as Windows with only the core Perl modules. We have run it as a PAR executable on Windows XP.

Use PAR::Packer on a Strawberry Perl distribution to create a self contained binary
```
# pp -v -o ftp_upload.exe ftp_upload.pl
```

## Authors

- Marcus van Dam (marcus _at_ marcusvandam.nl)

[1]: http://archive.org
