del *.res
del *.obj
ml /c /coff /Cp tt-cracktro.asm
rc tt-cracktro.Rc
link tt-cracktro.obj tt-cracktro.res
pause
del *.res
del *.obj
