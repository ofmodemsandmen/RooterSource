#ifndef __COMMON_H__
#define __COMMON_H__

#define ERR_FAIL -1
#define ERR_SUCCESS 0
#define LOG(fmt, args...)             \
    do                                \
    {                                 \
        fprintf(stderr, fmt, ##args); \
    } while (0)

#define ERR_RETURN(cond, val, fmt, args...) \
    do                                      \
    {                                       \
        if (cond)                           \
        {                                   \
            LOG(fmt, ##args);               \
            return val;                     \
        }                                   \
    } while (0)

#define ERR_LOG(cond, fmt, args...) \
    do                              \
    {                               \
        if (cond)                   \
            LOG(fmt, ##args);       \
    } while (0)

#define SAFETYFREE(v)        \
    do                       \
    {                        \
        if (v)               \
            free((void *)v); \
        v = NULL;            \
    } while (0)

#define SAFETYSTR(ptr) (ptr ? ptr : "")

#define STRING(fmt, args...) ({char buf[1024] = {'\0'}; snprintf(buf, sizeof(buf), fmt, ##args); buf; })

#endif //__COMMON_H__
