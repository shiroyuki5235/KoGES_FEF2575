KoGES FEF 최종 분석 코드 기탁 준비본 v1.0.0-rc2.2

현재 상태: 기존 실행 코드와 결과를 통합한 실행·검증 후보본입니다. 이 환경에서 원자료 분석을 다시 실행한 최종 검증본은 아닙니다.

실행 방법
1. ZIP 전체를 풀고 RStudio 작업 폴더를 이 폴더로 설정합니다.
2. 새 R 세션에서 R/00_Final_Analysis.R을 엽니다.
3. 작업 폴더에 원자료가 없으면 선택창에서 ASAS01to10_Processed.txt.gz를 선택합니다. 참조표/그림 폴더가 없으면 두 번째 선택창에서 이 패키지의 R/00_Final_Analysis.R을 선택합니다.
4. survival, openxlsx, zip이 설치되어 있어야 합니다. 기존 실행 환경은 R 4.6.1/survival 3.8-12였습니다.
5. Module 00부터 32까지 순차 실행합니다. RUN_ALL이나 source 드라이버, 이전 세션 객체는 필요하지 않습니다.
6. 현재 작업 폴더 아래에 결과 ZIP, 모든 분석표의 통합 Excel, 그림, sessionInfo가 생성됩니다.
7. Reproduction_checks.csv와 Analysis_status.csv를 확인하고 실제 실행 결과 ZIP을 검토한 뒤 정식 v1.0.0으로 기탁합니다.

유지한 내용
- 기존 Never/Single/Recurrent/Frequent 분류와 인원수, Model 1–4를 유지합니다.
- 60/70%와 확인형 사건은 기존에 보고된 탐색적 3그룹 민감도 결과의 재현입니다. 새로운 4그룹 cutoff 분석이 아닙니다.
- 산술 재구성은 차이 확인만 하며 공급 %PRED와 주분석 그룹을 덮어쓰지 않습니다.
- 기존 Figure 1/2 원본을 보존합니다. 새 KM 그림은 QC 표시본으로 별도 저장합니다.
- 분석표 CSV마다 Excel 시트를 만들고 INDEX 시트를 함께 저장합니다. 원고용 최종 표번호는 docs/Manuscript_code_map.csv에서 대조합니다.

현재 원고에 맞춘 분석 범위
현재 원고를 기준으로 주분석 네 그룹의 Model 1–4와 Table S4의 탐색적 세 그룹 Model 4/5/A/B/C 및 BMI 시간효과를 포함합니다. 기존 대상자·주분석 그룹·사건 정의는 유지합니다. Module 27–28에서 S4를 계산하고 기존 결과와 대조합니다. 로컬 재실행은 필요합니다.

FEF 예측식은 공개 자료만으로 확정되지 않았습니다. docs/FEF_Reference_Evidence_KO.txt와 기관 문의안을 참조하십시오. 장비명만 보고 Choi/Morris/Knudson/GLI 식으로 확정하지 않습니다.
