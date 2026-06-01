#!/bin/sh

set -e

# 配置
EXEC="/usr/local/bin/php"                  # PHP 可执行文件路径
ARGS="/var/www/v2board/artisan horizon"    # 传给 php 的参数
EXEC_USER="www-data"
PIDFILE="/tmp/v2board.pid"
WORKDIR="/var/www/v2board"

# 可选：从 /etc/default/v2board 加载额外参数
if [ -f /etc/default/v2board ]; then
    . /etc/default/v2board
fi

# 日志输出函数（不使用 LSB）
log_success_msg() { echo " [ OK ] $1"; }
log_failure_msg() { echo " [FAIL] $1" >&2; }
log_warning_msg() { echo " [WARN] $1" >&2; }
log_daemon_msg() { echo -n " $1... "; }

# 获取 PID（如果存在且进程存活）
get_pid() {
    if [ -f "$PIDFILE" ]; then
        pid=$(cat "$PIDFILE" 2>/dev/null) || true
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        fi
    fi
    return 1
}

is_running() {
    get_pid >/dev/null 2>&1
}

case "$1" in
    start)
        log_daemon_msg "Starting v2board"
        if is_running; then
            log_success_msg "already running (pid=$(get_pid))"
            exit 0
        fi
        # 使用 start-stop-daemon（如果存在）或直接用 nohup 方式启动
        su -s /bin/sh "$EXEC_USER" <<EOF
cd "$WORKDIR"
# 如果存在 setsid，则使用它创建新会话；否则直接后台运行，并尝试 disown
if command -v setsid >/dev/null 2>&1; then
    exec setsid $EXEC $ARGS >/dev/null 2>&1 &
else
    $EXEC $ARGS >/dev/null 2>&1 &
    disown
fi
echo \$! > "$PIDFILE"
EOF
        
        # 等待最多 5 秒确认启动
        for i in $(seq 1 5); do
            if is_running; then
                log_success_msg "started (pid=$(get_pid))"
                exit 0
            fi
            sleep 1
        done
        log_failure_msg "failed to start (timeout)"
        exit 1
        ;;

    stop)
        log_daemon_msg "Stopping v2board"
        if ! is_running; then
            log_success_msg "not running"
            exit 0
        fi
        pid=$(get_pid)
        # 先尝试优雅停止
        kill "$pid" 2>/dev/null || true
        # 等待最多 10 秒
        for i in $(seq 1 10); do
            if ! is_running; then
                break
            fi
            sleep 1
        done
        if is_running; then
            log_warning_msg "graceful stop failed, forcing kill"
            kill -9 "$pid" 2>/dev/null || true
            sleep 1
        fi
        rm -f "$PIDFILE"
        log_success_msg "stopped"
        ;;

    reload|force-reload)
        log_daemon_msg "Reloading v2board configuration"
        if ! is_running; then
            log_failure_msg "not running, cannot reload"
            exit 1
        fi
        pid=$(get_pid)
        if kill -HUP "$pid" 2>/dev/null; then
            log_success_msg "reload signal sent"
        else
            log_failure_msg "failed to send HUP signal"
            exit 1
        fi
        ;;

    restart)
        sh "$0" stop
        sleep 2
        sh "$0" start
        ;;

    try-restart)
        if is_running; then
            $0 restart
        else
            log_warning_msg "not running, nothing to restart"
            exit 0
        fi
        ;;

    status)
        if is_running; then
            echo "v2board is running (pid=$(get_pid))"
            exit 0
        else
            echo "v2board is not running"
            exit 3
        fi
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|try-restart|reload|force-reload|status}"
        exit 1
        ;;
esac

exit 0
