"""
Native accelerators for Parquet encoding and decoding.
"""
# cython: c_string_encoding=utf8

cdef extern from "string.h":
    void *memcpy(void *dest, const void *src, size_t n)

from cpython cimport (PyUnicode_AsUTF8String, PyUnicode_DecodeUTF8,
                      PyBytes_CheckExact, PyBytes_FromStringAndSize,
                      PyBytes_GET_SIZE, PyBytes_AS_STRING)
from cpython.unicode cimport PyUnicode_DecodeUTF8

import numpy as np
cimport numpy as np


_obj_dtype = np.dtype('object')


def array_encode_utf8(inp):
    """
    utf-8 encode all elements of a 1d ndarray of "object" dtype.
    A new ndarray of bytes objects is returned.
    """
    cdef:
        Py_ssize_t i, n
        np.ndarray[object, ndim=1] arr
        np.ndarray[object] result

    arr = np.array(inp)

    n = len(arr)
    result = np.empty(n, dtype=object)
    for i in range(n):
        # Fast utf-8 encoding, avoiding method call and codec lookup indirection
        result[i] = PyUnicode_AsUTF8String(arr[i])

    return result


def pack_byte_array(list items):
    """
    Pack a variable length byte array column.
    A bytes object is returned.
    """
    cdef:
        Py_ssize_t i, n, itemlen, total_size
        unsigned char *start
        unsigned char *data
        object val, out

    # Strategy: compute the total output size and allocate it in one go.
    n = len(items)
    total_size = 0
    for i in range(n):
        val = items[i]
        if not PyBytes_CheckExact(val):
            raise TypeError("expected list of bytes")
        total_size += 4 + PyBytes_GET_SIZE(val)

    out = PyBytes_FromStringAndSize(NULL, total_size)
    start = data = <unsigned char *> PyBytes_AS_STRING(out)

    # Copy data to output.
    for i in range(n):
        val = items[i]
        # `itemlen` should be >= 0, so no signed extension issues
        itemlen = PyBytes_GET_SIZE(val)
        data[0] = itemlen & 0xff
        data[1] = (itemlen >> 8) & 0xff
        data[2] = (itemlen >> 16) & 0xff
        data[3] = (itemlen >> 24) & 0xff
        data += 4
        memcpy(data, PyBytes_AS_STRING(val), itemlen)
        data += itemlen

    assert (data - start) == total_size
    return out


def unpack_byte_array(const unsigned char[::1] raw_bytes, Py_ssize_t n, const char utf=False):
    """
    Unpack a variable length byte array column.
    An array of bytes objects is returned.
    """
    cdef:
        Py_ssize_t i = 0
        char* ptr = <char*>&raw_bytes[0]
        int itemlen
        object[:] out = np.empty(n, dtype="object")

    while i < n:

        itemlen = (<int*> ptr)[0]
        ptr += 4
        if utf:
            out[i] = PyUnicode_DecodeUTF8(ptr, itemlen, "ignore")
        else:
            out[i] = PyBytes_FromStringAndSize(ptr, itemlen)
        ptr += itemlen
        i += 1

    return out
