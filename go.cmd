cd %~dp0
call c:\strawberry-perl-5.20.1.1-x64\path.cmd

:restart
@rem call plackup -p 5001 -s Twiggy -I lib -a bin\app.pl
call plackup -p 5001 -I lib -a bin\app.pl
goto restart