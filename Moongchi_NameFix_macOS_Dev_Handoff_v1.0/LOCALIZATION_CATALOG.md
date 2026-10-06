# Moongchi NameFix macOS — 문구/번역 인수인계

이 문서는 Windows 현재 리소스 157개 키 × 한국어/영어/일본어의 **원문 스냅샷**과 macOS 이식 규칙이다. 제품 요구사항은 [macOS Master](Moongchi_NameFix_macOS_Project_Master_v1.0.md)가 우선한다. 원문 표에 남은 Windows 표현을 그대로 Mac에 표시하지 않는다.

## 1. 변환 규칙

- `.xcstrings`로 옮기고 typed interpolation/locale별 숫자/복수형을 적용한다. `{0:N0}`, `{2:0}`, `{1}`는 .NET placeholder이므로 Swift에서 그대로 실행하지 않는다.
- 키마다 인수 개수/형식/의미를 정의하고 ko/en/ja parity를 테스트한다. 표의 `<br>`는 원래 줄바꿈이다. 사용자 문구에 HTML 태그로 출력하지 않는다.
- Source catalog는 이미 제거된 UI에서 쓰던 키도 보존한다. 키 존재가 해당 UI를 구현하라는 요구가 아니다.
- `Save`는 설정 화면에 사용하지 않는다. `InputHeading`, `DropHint`, `DropHelper`, `SafetyTitle`, `SafetyHint`, `WorkspaceSubtitle`, `ReadyToScan`을 메인 화면 곳곳에 모두 표시하지 않는다. Master의 간결한 화면 계약을 따른다.
- `Unsupported` 원문은 링크만 설명하지만 Mac에서는 패키지/볼륨 제약도 포함한다. 아래 중립 상태와 구체적 reason을 사용한다.
- `QueuedInputs`는 OS가 전달한 열기 요청을 보관할 때만 사용한다. busy 상태의 거부된 Finder drop을 “받았다”고 표시하지 않는다. 수신된 요청의 bounded queue는 transaction 후 검사만 수행하며 자동 Rename하지 않는다.
- `CancelBeforeClose`는 앱 종료를 안전 경계까지 보류하는 macOS lifecycle에 맞게 표시한다.
- 키 문자열을 변경하지 않고 원문을 무조건 복제하는 것보다 정확한 macOS 동작/번역이 우선이다.

## 2. macOS에서 교체할 기존 키

| Key | ko-KR | en-US | ja-JP |
|---|---|---|---|
| AccessHelp | macOS에서 접근을 거부했습니다. 폴더 권한을 확인하고 필요한 경우 폴더를 다시 선택하세요. | macOS denied access. Check folder permissions and select the folder again if needed. | macOSでアクセスが拒否されました。フォルダのアクセス権を確認し、必要に応じてフォルダを選び直してください。 |
| Unsupported | — 지원하지 않는 항목 | — Unsupported item | — 未対応の項目 |
| HelpBody | 파일·폴더 추가 → 변경 전후 확인 → 이름 수정. 요약을 누르면 필터가 적용됩니다. 선택 버튼은 표시 항목에 적용되며 숨은 선택 수가 목록 위에 표시됩니다. ⌘O 파일 추가 · ⇧⌘O 폴더 추가 · ⌘F 검색 · ⌘R 다시 검사. 목록에서 ⌘A 표시 항목 선택. 작업 기록에서 되돌릴 수 있습니다. | Add files or folders → review names → fix names. Summary counts filter the list. Selection actions affect visible items; hidden selections are counted above the list. ⌘O add files · ⇧⌘O add folders · ⌘F search · ⌘R rescan. In the list, ⌘A selects visible items. Undo is available in History. | ファイル・フォルダを追加 → 変更前後を確認 → 名前を修正。集計を押すと絞り込めます。選択操作は表示中の項目に適用され、非表示の選択数は一覧の上に表示されます。⌘O ファイル追加 · ⇧⌘O フォルダ追加 · ⌘F 検索 · ⌘R 再検査。一覧で⌘Aを押すと表示項目を選択します。履歴から元に戻せます。 |
| CancelBeforeClose | 안전하게 작업을 중단하고 종료하는 중입니다… | Stopping the operation safely before quitting… | 作業を安全に停止してから終了します… |
| DropUnavailable | 끌어놓기를 사용할 수 없습니다. 파일 추가 또는 폴더 추가를 사용하세요. | Drag and drop is unavailable. Use Add Files or Add Folders. | ドラッグ＆ドロップを利用できません。「ファイル追加」または「フォルダ追加」を使ってください。 |
| LinkedPathHelp | 의도하지 않은 위치를 변경하지 않도록 심볼릭 링크와 별칭은 따라가지 않습니다. | Symbolic links and aliases are not followed to prevent changes outside the selected location. | 意図しない場所を変更しないよう、シンボリックリンクやエイリアスの参照先はたどりません。 |

## 3. macOS 추가 키

| Key | ko-KR | en-US | ja-JP |
|---|---|---|---|
| VolumeNormalizationUnsupported | 이 파일시스템에서는 변경한 이름 형식을 유지할 수 없습니다. | This file system cannot preserve the requested name format. | このファイルシステムでは変更後の名前形式を保持できません。 |
| VolumeSafetyUnsupported | 이 위치에서 안전한 이름 변경을 확인할 수 없어 제외했습니다. | This location was skipped because safe renaming could not be verified. | この場所で安全な名前変更を確認できないため、対象から除外しました。 |
| PackageExcluded | 앱과 패키지는 기본 검사에서 제외됩니다. | Apps and packages are excluded from the default scan. | アプリとパッケージは既定の検査対象から除外されます。 |
| MountBoundaryExcluded | 다른 볼륨 내부는 자동으로 검사하지 않습니다. 필요하면 직접 추가하세요. | Other volumes are not scanned automatically. Add one explicitly if needed. | 別のボリューム内は自動検査しません。必要な場合は直接追加してください。 |
| SourceChanged | 검사 후 항목이 변경되어 제외했습니다. 다시 검사하세요. | This item changed after scanning and was skipped. Scan again. | 検査後に項目が変更されたため除外しました。再検査してください。 |
| ParentPermissionNeeded | 이름을 변경하려면 이 항목이 있는 폴더를 선택하세요. | Select the containing folder to allow this item to be renamed. | 名前を変更するには、この項目を含むフォルダを選択してください。 |
| SettingsSaveFailed | 설정을 저장하지 못했습니다. 변경 사항은 현재 실행에만 적용됩니다. | Settings could not be saved. Changes apply only to this session. | 設定を保存できませんでした。変更は今回の起動中のみ適用されます。 |
| NewerSchema | 더 최신 버전의 데이터입니다. 원본을 보존하고 변경을 제한합니다. | This data was created by a newer version. The original is preserved and changes are restricted. | 新しいバージョンで作成されたデータです。元のデータを保護するため変更を制限します。 |
| BusyDropRejected | 작업 중에는 항목을 추가할 수 없습니다. 완료 후 다시 놓으세요. | Items cannot be added during this operation. Drop them again when it finishes. | 作業中は項目を追加できません。完了後にもう一度ドロップしてください。 |
| SameAppearanceDifferentUnicode | 표시는 같지만 문자 구성이 다릅니다. | These names look the same but use different character sequences. | 見た目は同じですが、文字の構成が異なります。 |
| ClipboardTruncated | 분석 가능한 길이를 초과하여 일부만 표시합니다. | Only part of the text is shown because it exceeds the analysis limit. | 解析できる長さを超えているため、一部のみ表示しています。 |
| FinderServiceTitle | NameFix로 파일 이름 검사 | Inspect Names with NameFix | NameFixでファイル名を検査 |
| InstallationHint | Applications 폴더로 드래그해 설치하세요. | Drag the app to Applications to install it. | アプリをApplicationsフォルダにドラッグしてインストールしてください。 |
| JournalWriteFailed | 작업 기록을 저장하지 못해 이름 변경을 중단했습니다. | Renaming stopped because the operation record could not be saved. | 作業記録を保存できなかったため、名前変更を停止しました。 |
| RecoveryNeedsReview | 이전 작업의 상태를 확인해야 합니다. 파일과 기록은 보존되었습니다. | A previous operation needs review. Files and records have been preserved. | 前回の作業状態を確認する必要があります。ファイルと記録は保持されています。 |

## 4. 현재 Windows 리소스 전체 원문

아래 표는 자동 추출한 참조 원문이다. 위 override와 Master의 macOS 정책을 적용한 후 리소스를 생성한다.

| Key | ko-KR | en-US | ja-JP |
|---|---|---|---|
| DropHint | 파일·폴더를<br>끌어다 놓으세요 | Drop files and folders here | ファイル・フォルダーをドロップ |
| SafetyHint | 파일 내용은 수정하지 않습니다. 변경 전 이름을 미리 확인하세요. | File contents stay unchanged. Preview names before applying changes. | ファイルの内容は変更しません。実行前に名前を確認してください。 |
| AddFiles | 파일 추가 | Add files | ファイルを追加 |
| AddFolders | 폴더 추가 | Add folder | フォルダーを追加 |
| Cancel | 취소 | Cancel | キャンセル |
| Recursive | 하위 폴더 포함 | Include subfolders | サブフォルダーを含む |
| HideNormal | 정상 항목 숨기기 | Hide normal items | 正常な項目を非表示 |
| Search | 이름 또는 경로 검색 | Search names or paths | 名前・パスを検索 |
| Filter | 필터 | Filter | フィルター |
| Sort | 정렬 기준 | Sort by | 並べ替え |
| All | 전체 | All | すべて |
| Normal | ✓ 정상 | ✓ Normal | ✓ 正常 |
| NeedsNormalization | ● 수정 필요 | ● Needs correction | ● 修正が必要 |
| Mixed | ● 정규화 혼합 | ● Mixed forms | ● 混在 |
| Conflict | ⚠ 충돌 | ⚠ Conflict | ⚠ 競合 |
| InvalidUnicode | × 잘못된 Unicode | × Invalid Unicode | × 無効なUnicode |
| AccessDenied | × 접근 거부 | × Access denied | × アクセス拒否 |
| Unavailable | × 사용할 수 없음 | × Unavailable | × 利用不可 |
| Unsupported | — 링크 경로 제외 | — Linked path excluded | — リンクを除外 |
| Errors | 오류 | Errors | エラー |
| File | 파일 | File | ファイル |
| Directory | 폴더 | Folder | フォルダー |
| Name | 현재 이름 | Current name | 現在の名前 |
| Preview | 변경 후 이름 | New name | 変更後の名前 |
| Type | 유형 | Type | 種類 |
| Status | 상태 | Status | 状態 |
| Path | 경로 | Path | パス |
| Results | 검사 결과 | Scan results | 検査結果 |
| SelectNeeded | 수정 필요 항목 선택 | Select needed items | 修正が必要な項目を選択 |
| ClearSelection | 모두 해제 | Clear selection | 選択を解除 |
| Inspector | Unicode 상세 보기 | Unicode Inspector | Unicodeの詳細 |
| Settings | 설정 | Settings | 設定 |
| History | 작업 기록 / 되돌리기 | History / Undo | 履歴 / 元に戻す |
| Summary | 전체 {0:N0} · 수정 필요 {1:N0} · 충돌 {2:N0} · 오류 {3:N0} | Total {0:N0} · Needs correction {1:N0} · Conflicts {2:N0} · Errors {3:N0} | 合計 {0:N0} · 要修正 {1:N0} · 競合 {2:N0} · エラー {3:N0} |
| RenameCount | {0:N0}개 이름 수정 | Fix {0:N0} names | {0:N0}件の名前を修正 |
| Rename | 수정 실행 | Apply changes | 変更を適用 |
| Confirm | 이름 변경 확인 | Confirm name changes | 名前の変更を確認 |
| ConfirmBody | {0:N0}개 이름을 NFC 형식으로 변경합니다. 파일 내용은 변경하지 않습니다. 충돌 {1:N0}개는 제외됩니다. | Change {0:N0} names to NFC. Contents remain unchanged. Skip {1:N0} conflicting items. | {0:N0}件をNFC形式に変更します。内容は変更しません。競合する{1:N0}件を除外します。 |
| CloudWarning | 동기화 폴더의 이름 변경은 다른 기기로 전파될 수 있습니다. | Changes in a sync folder may propagate to other devices. | 同期フォルダーでの変更は他のデバイスにも反映される場合があります。 |
| Completed | 작업 완료 | Operation complete | 処理が完了しました |
| ResultSummary | 성공 {0:N0} · 건너뜀 {1:N0} · 오류 {2:N0} | Success {0:N0} · Skipped {1:N0} · Errors {2:N0} | 成功 {0:N0} · スキップ {1:N0} · エラー {2:N0} |
| Close | 닫기 | Close | 閉じる |
| Save | 저장 | Save | 保存 |
| NoChanges | 실행할 수 있는 변경이 없습니다. 다시 검사해 미리보기를 갱신하세요. | No safe changes remain. Rescan to refresh the preview. | 実行できる変更はありません。再検査してください。 |
| NoHistory | 아직 작업 기록이 없습니다. | No operations recorded yet. | 処理履歴はありません。 |
| OperationError | 작업을 완료하지 못했습니다. 작업 기록과 로컬 진단 로그를 확인하세요. | The operation could not finish. Check History and local diagnostic logs. | 処理を完了できませんでした。履歴とローカルログを確認してください。 |
| Cancelled | 검사를 취소했습니다. 완료된 항목만 표시합니다. | Scan cancelled. Partial results are shown. | 検査をキャンセルしました。検査済みの項目を表示します。 |
| ScanLimit | 안전 한도인 200,000개에 도달했습니다. 폴더를 나누어 검사하세요. | The 200,000 item safety limit was reached. Scan smaller folders separately. | 安全上の上限20万件に達しました。フォルダーを分けて検査してください。 |
| SettingsWarning | 설정을 읽을 수 없어 기본값을 사용합니다. 원본 설정 파일은 보존됩니다. | Settings could not be loaded. Safe defaults are active; the original file is preserved. | 設定を読み込めないため既定値を使用します。元のファイルは保持されます。 |
| CancelBeforeClose | 안전한 지점에서 중단 중입니다. 작업이 끝나면 다시 닫아주세요. | Stopping at a safe boundary. Close again after the operation finishes. | 安全な位置で停止します。処理終了後に閉じてください。 |
| Language | 언어 | Language | 言語 |
| Theme | 테마 | Theme | テーマ |
| System | 시스템 기본값 | System default | システムの既定 |
| Light | 밝게 | Light | ライト |
| Dark | 어둡게 | Dark | ダーク |
| ClearAfterRun | 완료 후 선택 해제 | Clear selection after completion | 完了後に選択を解除 |
| HistoryLimit | 완료된 작업 보존 개수 | Completed history to retain | 完了履歴の保存件数 |
| Diagnostics | 로컬 진단 로그 사용 | Enable local diagnostic logs | ローカル診断ログを有効にする |
| Undo | 선택 작업 되돌리기 | Undo selected operation | 選択した処理を元に戻す |
| UndoConfirm | 원래 이름 {0}개를 복원합니다. 충돌 {1}개는 제외합니다. 작업 이후 교체되거나 이동된 항목은 제외됩니다. | Restore {0} original names. {1} conflicts will be skipped. Files changed or replaced since the operation are excluded. | 元の名前を{0}件復元します。競合する{1}件と処理後に置換・移動された項目を除外します。 |
| RecoveryWarning | 중단된 작업을 확인해야 합니다. 작업 기록에서 원본·임시·대상 경로를 확인하세요. 자동으로 복구하지 않습니다. | An interrupted operation needs review. Open History to inspect source, temporary and destination paths. No automatic recovery is performed. | 中断された処理を確認してください。履歴で元・一時・変更先のパスを確認できます。自動復旧は行いません。 |
| HistoryWarning | 일부 작업 기록을 읽지 못했습니다. 원본은 보존되었습니다. | Some history files could not be read. Original files were preserved. | 一部の履歴を読み込めませんでした。元のファイルは保持されています。 |
| HistoryDetails | 작업 상세 | Operation details | 処理の詳細 |
| Prepared | 준비됨 | Prepared | 準備済み |
| TemporaryRenamed | 임시 이름 적용 | Temporary name applied | 一時名に変更済み |
| FinalRenamed | 최종 이름 적용 | Final name applied | 最終名に変更済み |
| Verified | 검증 완료 | Verified | 確認済み |
| RollbackStarted | 원래 이름 복구 중 | Rollback started | 復元を開始 |
| RolledBack | 원래 이름 복구됨 | Rolled back | 復元済み |
| Failed | 실패 | Failed | 失敗 |
| Skipped | 건너뜀 | Skipped | スキップ |
| RecoveryStatus | 복구 상태 확인 (읽기 전용) | Recovery inspection (read-only) | 復旧状態の確認（読み取り専用） |
| Original | 원본 | Original | 元 |
| Temporary | 임시 | Temporary | 一時 |
| Destination | 대상 | Destination | 変更先 |
| Current | 현재 | Current | 現在 |
| Present | 일치하는 항목 발견 | Matching entry found | 一致する項目あり |
| Missing | 일치하는 항목 없음 | No matching entry | 一致する項目なし |
| Ambiguous | 직접 확인 필요 | Manual review required | 手動確認が必要 |
| Scanning | {0:N0}개 항목 검사 중… | {0:N0} items scanned… | {0:N0}件を検査中… |
| NoInputs | 아직 추가한 항목이 없습니다. | No files or folders added yet. | まだ項目が追加されていません。 |
| NoResultsDescription | 검색어나 필터를 바꾸거나, 다른 파일·폴더를 추가해 보세요. | Try a different search or filter, or add more files and folders. | 検索やフィルターを変更するか、別のファイル・フォルダーを追加してください。 |
| WorkspaceTitle | 파일 이름 검사 | File name check | ファイル名チェック |
| HistoryShort | 작업 기록 | History | 履歴 |
| ConflictCaption | 이름 충돌 | Conflicts | 名前の競合 |
| NoResultsTitle | 표시할 항목이 없어요 | No matching items | 該当する項目がありません |
| DropHelper | 여러 폴더를 함께 추가하세요 | Add multiple folders together | 複数のフォルダーもまとめて追加できます |
| DropAction | 놓아서 검사 목록에 추가 | Drop to add to the scan | ドロップして検査に追加 |
| TotalCaption | 전체 항목 | Total items | すべての項目 |
| ResetInputs | 비우기 | Clear | クリア |
| EmptyTitle | 파일·폴더를 여기에 놓으세요 | Drop files or folders here | ファイル・フォルダーをここにドロップ |
| InputHeading | 항목 추가 | Add items | 項目を追加 |
| NeededCaption | 수정 가능 | Ready to fix | 修正可能 |
| InputCount | 추가한 위치 · {0} | Locations · {0} | 追加した場所 · {0} |
| InspectShort | 상세 보기 | Details | 詳細 |
| ClearSelectionShort | 선택 해제 | Deselect | 選択解除 |
| RemoveInput | 선택 위치 제거 | Remove selected location | 選択した場所を除外 |
| SafetyTitle | 안심하고 이름만 수정 | Only names change | 名前だけを安全に修正 |
| EmptyDescription | 파일 내용은 그대로, 이름만 수정합니다. | Only names change. File contents stay intact. | 内容はそのまま、名前だけを修正します。 |
| WorkspaceSubtitle | 흩어진 글자는 깔끔하게. 파일 내용은 그대로. | Clean, readable names. Your files stay the same. | 読みやすい名前に。ファイルの内容はそのまま。 |
| SelectedCaption | 선택됨 | Selected | 選択済み |
| SelectNeededShort | 수정 대상 선택 | Select fixable | 修正対象を選択 |
| ReadyToScan | 파일이나 폴더를 추가하면 바로 검사합니다. | Add files or folders to start scanning. | ファイルやフォルダーを追加すると検査を開始します。 |
| HelpBody | 파일·폴더 추가 → 미리보기 확인 → 이름 수정. 상단 요약 카드를 누르면 필터가 적용됩니다. 선택 버튼은 표시된 항목에만 적용되며 숨은 선택 개수는 목록 위에 표시됩니다. Ctrl+O 파일 추가 · Ctrl+Shift+O 폴더 추가 · Ctrl+F 검색 · F5 다시 검사 · 목록에서 Ctrl+A 표시 항목 선택. 작업 기록과 완료 창에서 안전하게 되돌릴 수 있습니다. | Add files or folders → review → rename. Click the summary cards to filter. Selection buttons affect visible rows; hidden selections are counted above the list. Ctrl+O: files · Ctrl+Shift+O: folders · Ctrl+F: search · F5: rescan · Ctrl+A in the list: select visible. History and the completion dialog provide safe Undo. | ファイル・フォルダーを追加 → 確認 → 名前を修正。上部のカードで絞り込めます。選択ボタンは表示中の項目に適用され、非表示の選択数も表示されます。Ctrl+O: ファイル · Ctrl+Shift+O: フォルダー · Ctrl+F: 検索 · F5: 再スキャン · 一覧でCtrl+A: 表示分を選択。履歴と完了画面から元に戻せます。 |
| ActivityCount | {0:N0} / {1:N0}개 · {2:0}% | {0:N0} / {1:N0} items · {2:0}% | {0:N0} / {1:N0}件 · {2:0}% |
| ActivityMetrics | {0:N0}개 처리 · {1} 경과 | {0:N0} processed · {1} elapsed | {0:N0}件処理 · 経過 {1} |
| ActivityCancel | 현재 항목을 마친 뒤 중지합니다 | Stopping after the current item | 現在の項目が終わると停止します |
| ActivityPreview | 미리보기 준비 중 | Preparing preview | プレビューを準備中 |
| ScanReady | 검사가 완료되었습니다 | Scan complete | 確認が完了しました |
| ActivityRename | 이름 수정 중 | Renaming | 名前を修正中 |
| HelpTitle | 사용 방법 | Quick guide | 使い方 |
| ActivityUndo | 원래 이름으로 복원 중 | Restoring names | 元の名前に復元中 |
| ActivityScan | 이름 검사 중 | Checking names | 名前を確認中 |
| CancelRequested | 중지 요청됨 | Stop requested | 停止を要求しました |
| AddFilesCompact | 파일 추가 | Files | ファイル |
| AddFoldersCompact | 폴더 추가 | Folders | フォルダー |
| CopyPath | 경로 복사 | Copy path | パスをコピー |
| SelectAllSafe | 전체 수정 가능 항목 선택 | Select all fixable items | 修正可能な項目をすべて選択 |
| RecentFolders | 최근 폴더 | Recent folders | 最近のフォルダー |
| UnavailableHelp | 현재 항목에 접근할 수 없습니다. 장치 연결이나 현재 위치를 확인하고 다시 검사하세요. | This item is no longer available. Reconnect the device or rescan its current location. | この項目にアクセスできません。デバイスの接続や現在の場所を確認し、再スキャンしてください。 |
| UndoNow | 이 작업 되돌리기 | Undo this operation | この操作を元に戻す |
| ResetFilters | 필터 초기화 | Reset filters | 絞り込み解除 |
| ClearAll | 전체 선택 해제 | Deselect all items | すべての選択を解除 |
| InvalidUnicodeHelp | 이름에 유효하지 않은 Unicode 문자열이 있어 안전하게 수정할 수 없습니다. | The name contains an invalid Unicode sequence and cannot be changed safely. | 名前に無効なUnicodeが含まれるため、安全に変更できません。 |
| InvertVisible | 표시 항목 선택 반전 | Invert visible selection | 表示分の選択を反転 |
| AccessHelp | Windows에서 접근을 거부했습니다. 폴더 권한을 확인한 후 다시 검사하세요. | Windows denied access. Check folder permissions and rescan. | Windowsによりアクセスが拒否されました。権限を確認して再スキャンしてください。 |
| ClearRecentFolders | 최근 폴더 기록 지우기 | Clear recent folders | 最近のフォルダー履歴を消去 |
| MoreActions | 추가 작업 | More actions | その他の操作 |
| RecentPrivacy | 기본값은 꺼짐입니다. 폴더 경로 최대 10개를 로컬에 저장하며, 끄면 저장된 목록을 지웁니다. | Off by default. Stores up to 10 folder paths locally. Turning this off clears the saved list. | 初期設定はオフです。最大10件のフォルダーパスをローカルに保存します。オフにすると保存済みの一覧を消去します。 |
| ChangeHelp | 이름의 표현 형식만 정리합니다. 파일 내용은 변경하지 않습니다. | Only the name representation changes. File contents stay unchanged. | 名前の表現形式のみを整えます。ファイルの内容は変更しません。 |
| SelectVisible | 표시 항목 선택 | Select visible | 表示分を選択 |
| SelectedOnly | 선택한 항목 | Selected items | 選択した項目 |
| SelectionScope | {0} / {1}개 표시 · 숨은 선택 {2} | {0} / {1} shown · {2} selected outside view | {0} / {1} 件表示 · 非表示の選択 {2} |
| RememberFolders | 이 기기에 최근 폴더 기억 | Remember recent folders on this device | このデバイスに最近のフォルダーを保存 |
| HiddenSelectionConfirm | 현재 검색·필터로 숨겨진 선택 항목 {0:N0}개도 포함됩니다. 확인하려면 취소 후 선택한 항목을 누르세요. | This includes {0:N0} selected items hidden by the current search or filter. Cancel and choose Selected items to review them. | 検索・フィルターで非表示の選択項目 {0:N0} 件も含まれます。確認するにはキャンセルして「選択した項目」を表示してください。 |
| ConflictHelp | 같은 이름의 대상이 이미 있거나 여러 항목의 변경 후 이름이 같습니다. 이 항목은 수정에서 제외됩니다. 폴더에서 중복을 확인하고 정리한 후 다시 검사하세요. | Another item already has this destination name, or multiple items would receive the same name. This item is excluded. Review the folder and rescan after resolving the duplicate. | 同じ名前の項目が存在するか、複数の項目が同じ名前になります。この項目は変更対象外です。フォルダーで重複を確認してから再スキャンしてください。 |
| NormalHelp | 이미 정상 형식의 이름입니다. 수정할 필요가 없습니다. | This name is already in the expected form. No change is needed. | 名前はすでに正常な形式です。変更は不要です。 |
| UndoLatest | 최근 작업 되돌리기… | Undo latest operation… | 最近の操作を元に戻す… |
| ClearVisible | 표시 선택 해제 | Deselect visible | 表示分を解除 |
| NoRecentFolders | 아직 최근 폴더가 없습니다 | No recent folders yet | 最近のフォルダーはありません |
| LinkedPathHelp | 선택한 폴더 밖으로 접근하지 않도록 연결된 경로는 검사에서 제외합니다. | Linked paths are excluded to avoid traversing outside the selected folder. | 選択したフォルダーの外へアクセスしないよう、リンク先は対象外です。 |
| Rescan | 다시 검사 | Rescan | 再スキャン |
| ColumnWidth | 현재 이름 열 너비 (← →, Home: 초기화) | Current name column width (← →, Home: reset) | 現在の名前の列幅（← →、Home: リセット） |
| Export | 내보내기 | Export | 出力 |
| MaskPaths | 파일 이름과 경로 숨기기 (권장) | Hide file names and paths (recommended) | ファイル名とパスを隠す（推奨） |
| NumberPreview | 번호가 붙은 이름 확인 | Review numbered names | 連番付きの名前を確認 |
| NoClipboardText | 클립보드에 문자열이 없습니다. | No text on the clipboard. | クリップボードにテキストがありません。 |
| ForwardFailed | 열린 창에 파일을 전달하지 못했습니다. 이 창을 닫고 기존 창에 파일을 추가하세요. | Could not deliver files to the open window. Close this window and add them to the existing window. | 起動中のウィンドウに送信できませんでした。この画面を閉じ、既存のウィンドウに追加してください。 |
| ExportDiagnostics | 진단 보고서 내보내기 | Export diagnostic report | 診断レポートを出力 |
| NumberExplanation | 제안된 이름을 확인하세요. 실행을 눌러야 이름이 변경됩니다. | Review every proposed name below. Nothing changes until you confirm. | 候補名を確認してください。実行するまで名前は変更されません。 |
| Exported | 진단 보고서를 저장했습니다. | Diagnostic report saved. | 診断レポートを保存しました。 |
| NumberConflicts | 충돌 이름에 번호 제안 | Suggest numbered names for conflicts | 重複名に連番を提案 |
| QueuedInputs | 파일을 받았습니다. 현재 작업이 끝나면 검사합니다. | Files received. They will be scanned when the current operation finishes. | ファイルを受信しました。現在の処理が終了するとチェックします。 |
| ClipboardInspect | 클립보드 문자열 분석 | Analyze clipboard text | クリップボードの文字列を分析 |
| CompactRows | 좁은 행 간격 | Compact rows | 行間を狭くする |
| OliveArchive | 올리브 아카이브 (레트로) | Olive Archive (Retro) | オリーブアーカイブ（レトロ） |
| DropUnavailable | 끌어놓기를 준비하지 못했습니다. 파일 추가 또는 폴더 추가 버튼을 사용해 주세요. | Drag and drop could not be initialized. Use Add files or Add folders. | ドラッグ＆ドロップを準備できませんでした。ファイル追加またはフォルダー追加をご利用ください。 |
