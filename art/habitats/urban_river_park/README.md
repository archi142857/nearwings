# 도시 하천 공원 임시 월드

디자인 캔버스 '새바라기 까치 디자인 시안'의 폴더블 화면 시안에서 뽑은 480×480칸 월드다(`tools/canvas_import.py`).

- `world_index.png`: 칸마다 색 번호. 색표는 `game/assets/habitats/urban_river_park/palettes.json`.
- `world_perches.json`: 시안 장면에서 새가 앉아 있던 자리를 보고 코드 세션이 잡은 횃대(월드 칸 좌표).

배경은 서식지마다 세로형·정사각형·가로형 세 벌을 쓴다(결정 기록 2026-10-22). 디자인 세션이 세 벌을 따로 그려 주기 전까지 `tools/temp_sets.py`가 이 월드에서 세 벌을 잘라 `game/assets/habitats/urban_river_park/<벌>/`에 만든다. 세 벌이 오면 이 폴더는 지운다.
