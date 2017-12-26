cd %~dp0
call c:\strawberry-perl-5.26.0.1-64bit\path.cmd

:restart
@rem call plackup -p 5001 -s Twiggy -I lib -a bin\app.pl
call plackup -l localhost:5002 -I lib -a bin\app.pl
goto restart