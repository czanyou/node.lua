
//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Log

#include "media_utils.h"

/** 当前日志输出级别. */
static uint32_t fLogLevel = 0;

/** 日志信息缓存区大小, 过长的日志信息内容将不会被显示. */
#define LOG_BUFFER_SIZE 255
	
/**
 * 设置日志输出级别
 */
int LogSetLevel(uint32_t level)
{
	fLogLevel = level;
	return 0;
}

/**
 * 整理源文件名, 只保留文件名(不包括完整路径)
 */
LPCSTR LogTrimFilename( LPCSTR file, char* path )
{
	if (file) {
		LPCSTR p = strrchr(file, '/');
		if (p) {
			file = p + 1;
		}

		p = strchr(file, '.');
		int size = p ? p - file : MAX_PATH;
		strncpy(path, file, size);
	}	
	return file;
}

/**
 * 输出调试日志信息
 */
void LogWrite( uint32_t level, LPCSTR file, int line, LPCSTR function, LPCSTR fmt, ... )
{
	if (level < fLogLevel) {
		return;
	}

	// Path
	char path[MAX_PATH];
	memset(path, 0, sizeof(path));
	LogTrimFilename(file, path);

	// Prefix
	char buf[LOG_BUFFER_SIZE + 255];
	memset(buf, 0, sizeof(buf));

	uint32_t   upTime	= time(NULL) % 1000;
	LPCSTR tag		= "";
	LPCSTR end		= "";

	int offset = snprintf(buf, MAX_PATH, "%04u#%s: ", upTime, function);
	//fputs(prefix, stderr);

	// Info
	va_list ap;

	// Print log to string ...
	va_start(ap, fmt);
	int size = vsnprintf(buf + offset, LOG_BUFFER_SIZE, fmt, ap);
	va_end(ap);

	// Line end
	char* p = buf + offset + size - 1;
	while (*p == '\r' || *p == '\n') {
		size--;
		p--;
	};
	
	snprintf(buf + offset + size, LOG_BUFFER_SIZE - size, " (%s:%d)\n", path, line);
	fputs(buf, stderr);
}

/** 返回当前系统时钟嘀嗒数, 单位为 1/1000000 秒. */
INT64 MediaGetTickCount()
{
	INT64 mtime = 0;
	static INT64 startTime = 0;

#if _WIN32
	mtime = GetTickCount() * 1000L;

#elif __linux
	mtime = times(NULL);
	mtime *= 10L;
	mtime += 1000L * 3600L * 24L;
	mtime *= 1000L;

#else
	struct timeval current;
	gettimeofday(&current, NULL);
	mtime = current.tv_sec * 1000000L + current.tv_usec;

#endif

	if (startTime == 0) {
		startTime = mtime;
	}

	mtime -= startTime;

	return mtime;
}
