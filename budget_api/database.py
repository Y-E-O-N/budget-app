# =============================================================================
# database.py - 데이터베이스 추상화 레이어
# =============================================================================
# SQLite (로컬/개발) 와 PostgreSQL (외부/프로덕션) 전환 가능
# 환경변수 DATABASE_URL이 있으면 PostgreSQL, 없으면 SQLite 사용
# =============================================================================
import os
import sqlite3
from abc import ABC, abstractmethod
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from typing import Optional, List, Dict, Any

# 시간대 설정
KST = ZoneInfo("Asia/Seoul")

# =============================================================================
# 추상 베이스 클래스
# =============================================================================
class DatabaseInterface(ABC):
    """데이터베이스 인터페이스 추상 클래스"""

    @abstractmethod
    def init_db(self) -> None:
        """데이터베이스 초기화 (테이블 생성)"""
        pass

    @abstractmethod
    def get_usage_count(self, device_id: str) -> int:
        """오늘의 사용 횟수 조회"""
        pass

    @abstractmethod
    def increment_usage(self, device_id: str) -> int:
        """사용 횟수 증가 및 현재 횟수 반환"""
        pass

    @abstractmethod
    def save_analysis_log(
        self,
        device_id: str,
        language: str,
        tone: str,
        request_data: str,
        response_data: Optional[str] = None,
        status_code: int = 200,
        error_message: Optional[str] = None
    ) -> None:
        """분석 요청/응답 로그 저장"""
        pass

    @abstractmethod
    def get_logs(self, limit: int = 50, device_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """로그 조회"""
        pass

    @abstractmethod
    def get_logs_stats(self) -> Dict[str, Any]:
        """로그 통계 조회"""
        pass

    @abstractmethod
    def cleanup_old_data(self, days: int = 7) -> None:
        """오래된 데이터 정리"""
        pass


def get_today_kst() -> str:
    """KST 기준 오늘 날짜 반환 (YYYY-MM-DD)"""
    return datetime.now(KST).strftime("%Y-%m-%d")


def get_now_kst() -> str:
    """KST 기준 현재 시간 반환 (YYYY-MM-DD HH:MM:SS)"""
    return datetime.now(KST).strftime("%Y-%m-%d %H:%M:%S")


# =============================================================================
# SQLite 구현 (로컬/개발용)
# =============================================================================
class SQLiteDatabase(DatabaseInterface):
    """SQLite 데이터베이스 구현"""

    def __init__(self, db_path: str):
        self.db_path = db_path

    def _get_connection(self):
        """SQLite 연결 생성"""
        return sqlite3.connect(self.db_path)

    def init_db(self) -> None:
        """데이터베이스 초기화"""
        conn = self._get_connection()
        cursor = conn.cursor()

        # device_id별 일일 사용량 추적 테이블
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS usage (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id TEXT NOT NULL,
                date TEXT NOT NULL,
                count INTEGER DEFAULT 0,
                UNIQUE(device_id, date)
            )
        """)

        # 분석 요청/응답 로그 테이블
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS analysis_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id TEXT NOT NULL,
                language TEXT,
                tone TEXT,
                request_data TEXT,
                response_data TEXT,
                status_code INTEGER,
                error_message TEXT,
                created_at TEXT NOT NULL
            )
        """)

        conn.commit()
        conn.close()

    def get_usage_count(self, device_id: str) -> int:
        """오늘의 사용 횟수 조회"""
        conn = self._get_connection()
        cursor = conn.cursor()
        today = get_today_kst()
        cursor.execute("SELECT count FROM usage WHERE device_id = ? AND date = ?", (device_id, today))
        result = cursor.fetchone()
        conn.close()
        return result[0] if result else 0

    def increment_usage(self, device_id: str) -> int:
        """사용 횟수 증가 및 현재 횟수 반환"""
        conn = self._get_connection()
        cursor = conn.cursor()
        today = get_today_kst()

        # UPSERT: 있으면 증가, 없으면 삽입
        cursor.execute("""
            INSERT INTO usage (device_id, date, count) VALUES (?, ?, 1)
            ON CONFLICT(device_id, date) DO UPDATE SET count = count + 1
        """, (device_id, today))
        conn.commit()

        # 현재 횟수 조회
        cursor.execute("SELECT count FROM usage WHERE device_id = ? AND date = ?", (device_id, today))
        result = cursor.fetchone()
        conn.close()
        return result[0] if result else 1

    def save_analysis_log(
        self,
        device_id: str,
        language: str,
        tone: str,
        request_data: str,
        response_data: Optional[str] = None,
        status_code: int = 200,
        error_message: Optional[str] = None
    ) -> None:
        """분석 요청/응답 로그 저장"""
        conn = self._get_connection()
        cursor = conn.cursor()
        created_at = get_now_kst()
        cursor.execute("""
            INSERT INTO analysis_logs
            (device_id, language, tone, request_data, response_data, status_code, error_message, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (device_id, language, tone, request_data, response_data, status_code, error_message, created_at))
        conn.commit()
        conn.close()

    def get_logs(self, limit: int = 50, device_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """로그 조회"""
        conn = self._get_connection()
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        if device_id:
            cursor.execute("""
                SELECT * FROM analysis_logs
                WHERE device_id = ?
                ORDER BY created_at DESC
                LIMIT ?
            """, (device_id, limit))
        else:
            cursor.execute("""
                SELECT * FROM analysis_logs
                ORDER BY created_at DESC
                LIMIT ?
            """, (limit,))

        rows = cursor.fetchall()
        conn.close()
        return [dict(row) for row in rows]

    def get_logs_stats(self) -> Dict[str, Any]:
        """로그 통계 조회"""
        conn = self._get_connection()
        cursor = conn.cursor()

        # 전체 요청 수
        cursor.execute("SELECT COUNT(*) FROM analysis_logs")
        total = cursor.fetchone()[0]

        # 성공 수
        cursor.execute("SELECT COUNT(*) FROM analysis_logs WHERE status_code = 200")
        success = cursor.fetchone()[0]

        # 기기별 요청 수
        cursor.execute("""
            SELECT device_id, COUNT(*) as count
            FROM analysis_logs
            GROUP BY device_id
            ORDER BY count DESC
        """)
        by_device = cursor.fetchall()

        # 날짜별 요청 수
        cursor.execute("""
            SELECT DATE(created_at) as date, COUNT(*) as count
            FROM analysis_logs
            GROUP BY DATE(created_at)
            ORDER BY date DESC
            LIMIT 7
        """)
        by_date = cursor.fetchall()

        conn.close()

        return {
            "total_requests": total,
            "success_count": success,
            "error_count": total - success,
            "by_device": [{"device_id": d[0], "count": d[1]} for d in by_device],
            "by_date": [{"date": d[0], "count": d[1]} for d in by_date]
        }

    def cleanup_old_data(self, days: int = 7) -> None:
        """오래된 데이터 정리"""
        conn = self._get_connection()
        cursor = conn.cursor()
        cutoff = (datetime.now(KST) - timedelta(days=days)).strftime("%Y-%m-%d")
        cursor.execute("DELETE FROM usage WHERE date < ?", (cutoff,))
        conn.commit()
        conn.close()


# =============================================================================
# PostgreSQL 구현 (외부/프로덕션용)
# =============================================================================
class PostgreSQLDatabase(DatabaseInterface):
    """PostgreSQL 데이터베이스 구현 (psycopg2 사용)"""

    def __init__(self, database_url: str):
        self.database_url = database_url
        self._pool = None

    def _get_connection(self):
        """PostgreSQL 연결 생성"""
        import psycopg2
        return psycopg2.connect(self.database_url)

    def init_db(self) -> None:
        """데이터베이스 초기화"""
        conn = self._get_connection()
        cursor = conn.cursor()

        # device_id별 일일 사용량 추적 테이블
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS usage (
                id SERIAL PRIMARY KEY,
                device_id TEXT NOT NULL,
                date TEXT NOT NULL,
                count INTEGER DEFAULT 0,
                UNIQUE(device_id, date)
            )
        """)

        # 분석 요청/응답 로그 테이블
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS analysis_logs (
                id SERIAL PRIMARY KEY,
                device_id TEXT NOT NULL,
                language TEXT,
                tone TEXT,
                request_data TEXT,
                response_data TEXT,
                status_code INTEGER,
                error_message TEXT,
                created_at TEXT NOT NULL
            )
        """)

        # 인덱스 생성 (성능 최적화)
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_usage_device_date ON usage(device_id, date)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_logs_device_id ON analysis_logs(device_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_logs_created_at ON analysis_logs(created_at)")

        conn.commit()
        cursor.close()
        conn.close()

    def get_usage_count(self, device_id: str) -> int:
        """오늘의 사용 횟수 조회"""
        conn = self._get_connection()
        cursor = conn.cursor()
        today = get_today_kst()
        cursor.execute("SELECT count FROM usage WHERE device_id = %s AND date = %s", (device_id, today))
        result = cursor.fetchone()
        cursor.close()
        conn.close()
        return result[0] if result else 0

    def increment_usage(self, device_id: str) -> int:
        """사용 횟수 증가 및 현재 횟수 반환"""
        conn = self._get_connection()
        cursor = conn.cursor()
        today = get_today_kst()

        # UPSERT: PostgreSQL 문법
        cursor.execute("""
            INSERT INTO usage (device_id, date, count) VALUES (%s, %s, 1)
            ON CONFLICT(device_id, date) DO UPDATE SET count = usage.count + 1
            RETURNING count
        """, (device_id, today))

        result = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        return result[0] if result else 1

    def save_analysis_log(
        self,
        device_id: str,
        language: str,
        tone: str,
        request_data: str,
        response_data: Optional[str] = None,
        status_code: int = 200,
        error_message: Optional[str] = None
    ) -> None:
        """분석 요청/응답 로그 저장"""
        conn = self._get_connection()
        cursor = conn.cursor()
        created_at = get_now_kst()
        cursor.execute("""
            INSERT INTO analysis_logs
            (device_id, language, tone, request_data, response_data, status_code, error_message, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (device_id, language, tone, request_data, response_data, status_code, error_message, created_at))
        conn.commit()
        cursor.close()
        conn.close()

    def get_logs(self, limit: int = 50, device_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """로그 조회"""
        conn = self._get_connection()
        cursor = conn.cursor()

        if device_id:
            cursor.execute("""
                SELECT id, device_id, language, tone, request_data, response_data,
                       status_code, error_message, created_at
                FROM analysis_logs
                WHERE device_id = %s
                ORDER BY created_at DESC
                LIMIT %s
            """, (device_id, limit))
        else:
            cursor.execute("""
                SELECT id, device_id, language, tone, request_data, response_data,
                       status_code, error_message, created_at
                FROM analysis_logs
                ORDER BY created_at DESC
                LIMIT %s
            """, (limit,))

        columns = ['id', 'device_id', 'language', 'tone', 'request_data',
                   'response_data', 'status_code', 'error_message', 'created_at']
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        return [dict(zip(columns, row)) for row in rows]

    def get_logs_stats(self) -> Dict[str, Any]:
        """로그 통계 조회"""
        conn = self._get_connection()
        cursor = conn.cursor()

        # 전체 요청 수
        cursor.execute("SELECT COUNT(*) FROM analysis_logs")
        total = cursor.fetchone()[0]

        # 성공 수
        cursor.execute("SELECT COUNT(*) FROM analysis_logs WHERE status_code = 200")
        success = cursor.fetchone()[0]

        # 기기별 요청 수
        cursor.execute("""
            SELECT device_id, COUNT(*) as count
            FROM analysis_logs
            GROUP BY device_id
            ORDER BY count DESC
        """)
        by_device = cursor.fetchall()

        # 날짜별 요청 수
        cursor.execute("""
            SELECT DATE(created_at) as date, COUNT(*) as count
            FROM analysis_logs
            GROUP BY DATE(created_at)
            ORDER BY date DESC
            LIMIT 7
        """)
        by_date = cursor.fetchall()

        cursor.close()
        conn.close()

        return {
            "total_requests": total,
            "success_count": success,
            "error_count": total - success,
            "by_device": [{"device_id": d[0], "count": d[1]} for d in by_device],
            "by_date": [{"date": str(d[0]), "count": d[1]} for d in by_date]
        }

    def cleanup_old_data(self, days: int = 7) -> None:
        """오래된 데이터 정리"""
        conn = self._get_connection()
        cursor = conn.cursor()
        cutoff = (datetime.now(KST) - timedelta(days=days)).strftime("%Y-%m-%d")
        cursor.execute("DELETE FROM usage WHERE date < %s", (cutoff,))
        conn.commit()
        cursor.close()
        conn.close()


# =============================================================================
# 데이터베이스 팩토리 함수
# =============================================================================
def create_database() -> DatabaseInterface:
    """
    환경변수에 따라 적절한 데이터베이스 인스턴스 생성

    - DATABASE_URL이 있으면 PostgreSQL 사용
    - 없으면 SQLite 사용 (기본값)

    사용법:
        db = create_database()
        db.init_db()
        count = db.get_usage_count("device-123")
    """
    database_url = os.getenv("DATABASE_URL")

    if database_url:
        # PostgreSQL 사용
        print(f"[DB] Using PostgreSQL: {database_url[:30]}...")
        return PostgreSQLDatabase(database_url)
    else:
        # SQLite 사용 (기본값)
        db_path = os.path.join(os.path.dirname(__file__), "usage.db")
        print(f"[DB] Using SQLite: {db_path}")
        return SQLiteDatabase(db_path)
