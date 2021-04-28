"""setup.py for fastparquet"""

from setuptools import setup, Extension, find_packages
from setuptools.command.build_ext import build_ext
import numpy as np
from Cython.Build import cythonize

modules = [
    Extension(
        "fastparquet.speedups",
        ["fastparquet/speedups.pyx"],
        include_dirs=[np.get_include()],
        define_macros=[("NPY_NO_DEPRECATED_API", "NPY_1_7_API_VERSION")],
    ),
    Extension(
        "fastparquet.cencoding",
        ["fastparquet/cencoding.pyx"],
    ),
]

setup(
    packages=["fastparquet"],
    extras_require={
        "brotli": ["brotli"],
        "lz4": ["lz4 >= 0.19.1"],
        "lzo": ["python-lzo"],
        "snappy": ["python-snappy"],
        "zstandard": ["zstandard"],
        "zstd": ["zstd"],
    },
    tests_require=[
        "pytest",
        "python-snappy",
        "lz4 >= 0.19.1",
        "zstandard",
        "zstd",
    ],
    package_data={"fastparquet": ["*.thrift"]},
    include_package_data=True,
    exclude_package_data={"fastparquet": ["test/*"]},
    ext_modules=cythonize(
        modules,
        language_level=3,
        annotate=True,
    ),
)
