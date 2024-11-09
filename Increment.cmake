# Basic definitions
set(HEADER_FILE "increment.h")
set(CACHE_FILE "BuildNumberCache.txt")

# Initialize the incremented value
if(EXISTS ${CACHE_FILE})
    file(READ ${CACHE_FILE} INCREMENTED_VALUE)
    string(STRIP ${INCREMENTED_VALUE} INCREMENTED_VALUE)  # Remove any whitespace
    math(EXPR INCREMENTED_VALUE "${INCREMENTED_VALUE}+1")
else()
    set(INCREMENTED_VALUE "1")
endif()

# Write the incremented value back to the cache file
file(WRITE ${CACHE_FILE} "${INCREMENTED_VALUE}")

# Create the header file with the incremented value
file(WRITE ${HEADER_FILE} "#ifndef INCREMENT_H\n#define INCREMENT_H\n\n#define INCREMENTED_VALUE ${INCREMENTED_VALUE}\n\n#endif")
