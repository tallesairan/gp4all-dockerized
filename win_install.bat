@echo off

@rem This script will install miniconda and git with all dependencies for this project
@rem This enables a user to install this project without manually installing conda and git.

@rem workaround for broken Windows installs
set PATH=%PATH%;%SystemRoot%\system32

cd /D "%~dp0"

echo "%cd%"| findstr /C:" " >nul && call :PrintBigMessage "This script relies on Miniconda which can not be silently installed under a path with spaces." && goto end
call :PrintBigMessage "WARNING: This script relies on Miniconda which will fail to install if the path is too long."
set "SPCHARMESSAGE="WARNING: Special characters were detected in the installation path!" "         This can cause the installation to fail!""
echo "%CD%"| findstr /R /C:"[!#\$%&()\*+,;<=>?@\[\]\^`{|}~]" >nul && (
  call :PrintBigMessage %SPCHARMESSAGE%
)
set SPCHARMESSAGE=

pause
cls

echo "      ___       ___           ___       ___       ___           ___      "
echo "     /\__\     /\  \         /\__\     /\__\     /\__\         /\  \     "
echo "    /:/  /    /::\  \       /:/  /    /:/  /    /::|  |       /::\  \    "
echo "   /:/  /    /:/\:\  \     /:/  /    /:/  /    /:|:|  |      /:/\ \  \   "
echo "  /:/  /    /:/  \:\  \   /:/  /    /:/  /    /:/|:|__|__   _\:\~\ \  \  "
echo " /:/__/    /:/__/ \:\__\ /:/__/    /:/__/    /:/ |::::\__\ /\ \:\ \ \__\ "
echo " \:\  \    \:\  \ /:/  / \:\  \    \:\  \    \/__/~~/:/  / \:\ \:\ \/__/ "
echo "  \:\  \    \:\  /:/  /   \:\  \    \:\  \         /:/  /   \:\ \:\__\   "
echo "   \:\  \    \:\/:/  /     \:\  \    \:\  \       /:/  /     \:\/:/  /   "
echo "    \:\__\    \::/  /       \:\__\    \:\__\     /:/  /       \::/  /    "
echo "     \/__/     \/__/         \/__/     \/__/     \/__/         \/__/     "
echo " By ParisNeo"

echo Please specify if you want to use a GPU or CPU. Note thaty only NVidea GPUs are supported?
echo A) Enable GPU
echo B) Run CPU mode
set /p "gpuchoice=Input> "
set gpuchoice=%gpuchoice:~0,1%

if /I "%gpuchoice%" == "A" (
  set "PACKAGES_TO_INSTALL=python=3.10 cuda-toolkit ninja git"
  set "CHANNEL=-c nvidia/label/cuda-11.7.0 -c nvidia -c conda-forge"
) else if /I "%gpuchoice%" == "B" (
  set "PACKAGES_TO_INSTALL=python=3.10 ninja git"
  set "CHANNEL=-c conda-forge"
) else (
  echo Invalid choice. Exiting...
  exit
)

@rem better isolation for virtual environment
SET "CONDA_SHLVL="
SET PYTHONNOUSERSITE=1
SET "PYTHONPATH="
SET "PYTHONHOME="
SET "TEMP=%cd%\installer_files\temp"
SET "TMP=%cd%\installer_files\temp"

set MINICONDA_DIR=%cd%\installer_files\miniconda3
set INSTALL_ENV_DIR=%cd%\installer_files\lollms_env
set MINICONDA_DOWNLOAD_URL=https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe
set REPO_URL=https://github.com/ParisNeo/lollms-webui.git

if not exist "%MINICONDA_DIR%\Scripts\conda.exe" (
  @rem download miniconda
  echo Downloading Miniconda installer from %MINICONDA_DOWNLOAD_URL%
  call curl -LOk "%MINICONDA_DOWNLOAD_URL%"

  @rem install miniconda
  echo. && echo Installing Miniconda To "%MINICONDA_DIR%" && echo Please Wait... && echo.
  start "" /W /D "%cd%" "Miniconda3-latest-Windows-x86_64.exe" /InstallationType=JustMe /NoShortcuts=1 /AddToPath=0 /RegisterPython=0 /NoRegistry=1 /S /D=%MINICONDA_DIR% || ( echo. && echo Miniconda installer not found. && goto end )
  del /q "Miniconda3-latest-Windows-x86_64.exe"
  if not exist "%MINICONDA_DIR%\Scripts\activate.bat" ( echo. && echo Miniconda install failed. && goto end )
)

@rem activate miniconda
call "%MINICONDA_DIR%\Scripts\activate.bat" || ( echo Miniconda hook not found. && goto end )

@rem create the installer env
if not exist "%INSTALL_ENV_DIR%" (
  echo Packages to install: %PACKAGES_TO_INSTALL%
  call conda create --no-shortcuts -y -k -p "%INSTALL_ENV_DIR%" %CHANNEL% %PACKAGES_TO_INSTALL% || ( echo. && echo Conda environment creation failed. && goto end )
  if /I "%gpuchoice%" == "A" call conda run --live-stream -p "%INSTALL_ENV_DIR%" python -m pip install torch==2.0.1+cu117 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu117|| ( echo. && echo Pytorch installation failed.&& goto end )
  if /I "%gpuchoice%" == "B" call conda run --live-stream -p "%INSTALL_ENV_DIR%" python -m pip install torch torchvision torchaudio|| ( echo. && echo Pytorch installation failed.&& goto end )
)

@rem check if conda environment was actually created
if not exist "%INSTALL_ENV_DIR%\python.exe" ( echo. && echo Conda environment is empty. && goto end )

@rem activate installer env
call conda activate "%INSTALL_ENV_DIR%" || ( echo. && echo Conda environment activation failed. && goto end )

@rem set default cuda toolkit to the one in the environment
set "CUDA_PATH=%INSTALL_ENV_DIR%"

@rem clone the repository
if exist lollms-webui\ (
  cd lollms-webui
  git pull
) else (
  git clone https://github.com/ParisNeo/lollms-webui.git
  cd lollms-webui || goto end
)

@rem Loop through each "git+" requirement and uninstall it   workaround for inconsistent git package updating
for /F "delims=" %%a in (requirements.txt) do echo "%%a"| findstr /C:"git+" >nul&& for /F "tokens=4 delims=/" %%b in ("%%a") do for /F "delims=@" %%c in ("%%b") do python -m pip uninstall -y %%c

@rem install the pip requirements
call python -m pip install -r requirements.txt --upgrade

@rem create launcher
if exist ..\win_run.bat (
    echo Win run found
) else (
  copy win_run.bat ..\
  goto end
)

if exist ..\win_update.bat (
    echo Win update found
) else (
  copy win_update.bat ..\
  goto end
)

:PrintBigMessage
echo. && echo.
echo *******************************************************************
for %%M in (%*) do echo * %%~M
echo *******************************************************************
echo. && echo.
exit /b

:end
pause
