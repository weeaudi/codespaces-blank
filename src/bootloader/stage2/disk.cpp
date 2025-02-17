#include "disk.h"

disk::disk(DiskReadFunc readFunc)
{
    this->readFunc = readFunc;
}