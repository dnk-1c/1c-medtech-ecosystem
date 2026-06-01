#!/usr/bin/env python3
"""
scripts/ai_review.py — AI Code Review через Claude API
Используется в GitHub Actions и GitLab CI.

Запуск: python3 scripts/ai_review.py <path_to_diff_file>
Требует: ANTHROPIC_API_KEY в переменных окружения
"""

import sys
import os
import anthropic

REVIEW_PROMPT = """Ты — эксперт по разработке расширений 1С:Предприятие 8.3.
Проведи code review следующего diff по этим критериям:

1. Стандарты BSL-кода:
   - Именование (ГлаголСуществительное для процедур, СуществительноеПрилагательное для переменных)
   - Запросы в циклах (антипаттерн)
   - Конкатенация строк вместо параметров запроса (антипаттерн)
   - Транзакции должны иметь Попытка/КонецПопытки

2. Правила расширений 1С:
   - Все новые объекты должны иметь префикс расширения
   - Нет изменения типов существующих реквизитов
   - Нет дублирования типового функционала

3. Качество кода:
   - Смешивание UI-логики и бизнес-логики
   - Глобальные переменные для передачи данных
   - Отсутствие обработки исключений

Формат ответа:
- Если замечаний нет: напиши "✅ Code review пройден"
- Если есть замечания: перечисли их с указанием строки и описанием проблемы
- Будь конкретным и кратким
"""

def main():
    if len(sys.argv) < 2:
        print("Использование: python3 ai_review.py <diff_file>")
        sys.exit(1)

    diff_file = sys.argv[1]

    if not os.path.exists(diff_file):
        print(f"Файл не найден: {diff_file}")
        sys.exit(1)

    with open(diff_file, "r", encoding="utf-8") as f:
        diff_content = f.read()

    if not diff_content.strip():
        print("✅ Нет изменений BSL-файлов для проверки")
        sys.exit(0)

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("❌ ANTHROPIC_API_KEY не задан")
        sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key)

    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1000,
        messages=[
            {
                "role": "user",
                "content": f"{REVIEW_PROMPT}\n\n---\nDIFF:\n```\n{diff_content[:8000]}\n```"
            }
        ]
    )

    review_result = message.content[0].text
    print(review_result)

    # Завершить с ошибкой если есть замечания (для блокировки merge)
    if "✅" not in review_result:
        sys.exit(1)

if __name__ == "__main__":
    main()
