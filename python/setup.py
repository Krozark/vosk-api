import os
import setuptools
import shutil
import glob
import platform

# Figure out environment for cross-compile
vosk_source = os.getenv("VOSK_SOURCE", os.path.abspath(os.path.join(os.path.dirname(__file__),
    "..")))
system = os.environ.get('VOSK_SYSTEM', platform.system())
architecture = os.environ.get('VOSK_ARCHITECTURE', platform.architecture()[0])
machine = os.environ.get('VOSK_MACHINE', platform.machine())

# Copy precompmilled libraries
for lib in glob.glob(os.path.join(vosk_source, "src/lib*.*")):
    print ("Adding library", lib)
    shutil.copy(lib, "vosk")

def platform_tag():
    """Wheel platform tag of the libvosk binary that is packaged (the wheel itself is pure Python)."""
    if system == 'Darwin':
        return 'macosx_11_0_universal2'
    if system == 'Windows':
        if architecture == '32bit':
            return 'win32'
        return 'win_arm64' if machine == 'ARM64' else 'win_amd64'
    if system == 'Linux':
        if os.environ.get('VOSK_VARIANT') == '-musl':
            return 'musllinux_1_2_' + machine
        if machine == 'aarch64' and architecture == '64bit':
            return 'manylinux_2_28_aarch64'  # built on the manylinux_2_28 image
        return 'linux_' + {'x86': 'i686'}.get(machine, machine)
    raise TypeError("Unknown build environment")


# Create OS-dependent, but Python-independent wheels.
try:
    from wheel.bdist_wheel import bdist_wheel
except ImportError:
    cmdclass = {}
else:
    class bdist_wheel_tag_name(bdist_wheel):
        def get_tag(self):
            return 'py3', 'none', platform_tag()
    cmdclass = {'bdist_wheel': bdist_wheel_tag_name}

with open("README.md", "rb") as fh:
    long_description = fh.read().decode("utf-8")

setuptools.setup(
    name="vosk",
    version="0.3.75",
    author="Alpha Cephei Inc",
    author_email="contact@alphacephei.com",
    description="Offline open source speech recognition API based on Kaldi and Vosk",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/alphacep/vosk-api",
    packages=setuptools.find_packages(),
    package_data = {'vosk': ['*.so', '*.dll', '*.dylib']},
    entry_points = {
        'console_scripts': ['vosk-transcriber=vosk.transcriber.cli:main'],
    },
    include_package_data=True,
    classifiers=[
        'Programming Language :: Python :: 3',
        'License :: OSI Approved :: Apache Software License',
        'Operating System :: Microsoft :: Windows',
        'Operating System :: POSIX :: Linux',
        'Operating System :: MacOS :: MacOS X',
        'Topic :: Software Development :: Libraries :: Python Modules'
    ],
    cmdclass=cmdclass,
    python_requires='>=3',
    zip_safe=False, # Since we load so file from the filesystem, we can not run from zip file
    setup_requires=['cffi>=1.0', 'requests', 'tqdm', 'srt', 'websockets'],
    install_requires=['cffi>=1.0', 'requests', 'tqdm', 'srt', 'websockets'],
    cffi_modules=['vosk_builder.py:ffibuilder'],
)
