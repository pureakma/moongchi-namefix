from pathlib import Path
import json,re,shutil
root=Path(__file__).resolve().parent.parent
handoff=root/'Moongchi_NameFix_macOS_Dev_Handoff_v1.0'
text=(handoff/'LOCALIZATION_CATALOG.md').read_text()
sections=text.split('## 4.')
def rows(s):
    out={}
    for l in s.splitlines():
        c=[x.strip() for x in l.split('|')]
        if len(c)==6 and c[1] not in ('Key','---'):
            out[c[1]]=[re.sub(r'\{(\d+)(?::[^}]+)?\}',r'{\1}',x.replace('<br>','\n')) for x in c[2:5]]
    return out
catalog=rows(sections[1]);catalog.update(rows(sections[0]))
extra={
'NeedsNormalization':['● 분해형','● Decomposed','● 分解形'],
'Normal':['✓ 조합형 (NFC)','✓ NFC form','✓ 合成形 (NFC)'],
'Mixed':['● 혼합형','● Mixed forms','● 混在形'],
'CanonicalVariant':['● 다른 문자 구성','● Alternate form','● 異なる構成'],
'NeededCaption':['NFC 변환 가능','Can use NFC','NFC変換可能'],
'HideNormal':['조합형 숨기기','Hide NFC names','合成形を非表示'],
'NormalHelp':['이미 NFC 형식입니다. 이름의 문자 구성을 바꿀 필요가 없습니다.','Already in NFC form. No change to character composition is needed.','すでにNFC形式です。文字構成の変更は不要です。'],
'ChangeHelp':['파일이 손상된 것은 아닙니다. 이름의 문자 구성을 NFC로 통일할 수 있으며 파일 내용은 변경하지 않습니다.','The file is not damaged. Its name can use NFC without changing file contents.','ファイルの破損ではありません。内容を変えずに名前の文字構成をNFCに統一できます。'],
'NormalizationNotice':['겉모양은 같아도 문자 구성이 다를 수 있습니다. 분해형은 오류가 아니며 조합형(NFC)으로 통일할 수 있습니다. 작은 칸은 실제 이름이 아닌 문자 구성 설명입니다.','Names can look identical while their characters differ. Decomposed names are not errors; you can normalize them to NFC. Small boxes explain the characters, not the literal name.','同じ見た目でも文字構成が異なることがあります。分解形はエラーではなく、NFCに統一できます。小さな枠は実際の名前ではなく文字構成の説明です。'],
'CompositionTitle':['전체 문자 구성 비교','Full character comparison','すべての文字構成を比較'],
'CompositionLegend':['작은 칸은 내부 문자를 풀어 쓴 설명입니다. 파일명 자체에 공백이나 구분 기호를 추가하지 않습니다.','The boxes explain individual characters. No spaces or separators are added to the actual filename.','枠は内部の文字を分けた説明です。実際のファイル名に空白や区切り文字は追加しません。'],
'CompositionScalarLegend':['한글 자모는 읽기 쉬운 독립 모양으로, 결합 부호는 점선 원과 함께 표시합니다. U+ 코드는 실제 문자의 값입니다.','Hangul jamo use standalone display glyphs; combining marks use a dotted circle. U+ codes identify the actual characters.','ハングル字母は独立した形、結合記号は点線の丸と表示します。U+コードは実際の文字の値です。'],
'MoreCharacterChanges':['다른 {0}개 글자도 달라집니다. 상세 보기에서 전체 구성을 확인하세요.','{0} more characters change. Open Details for the full comparison.','ほかに{0}文字が変わります。詳細ですべての構成を確認できます。'],
'CharacterPosition':['{0}번째 글자','Character {0}','{0}文字目'],
'CompositionChanges':['구성 변경','Composition changes','構成を変更'],
'CompositionUnchanged':['그대로 유지','Unchanged','変更なし'],
'OriginalComposition':['현재 구성','Current composition','現在の構成'],
'NFCComposition':['NFC 구성','NFC composition','NFCの構成'],

'ColumnWidth':['현재 이름 열 너비','Current name column width','現在の名前の列幅'],
'SettingsAutomatic':['변경한 설정은 바로 적용되고 자동으로 저장됩니다.','Changes apply immediately and save automatically.','変更はすぐに適用され、自動で保存されます。'],
'ColumnWidthHelp':['넓은 창의 결과 표에 적용됩니다. 좁은 창에서는 두 이름을 세로로 표시합니다.','Applies to the results table in wide windows. Narrow windows show the two names vertically.','広いウインドウの結果表に適用されます。狭い場合は2つの名前を縦に表示します。'],

'CompletedWithErrors':['일부 항목을 변경하지 못했습니다','Completed with errors','一部の項目を変更できませんでした'],
'SourceChangedAfterMove':['다른 앱의 변경을 감지해 중단했습니다. 항목이 임시 이름에 남아 있을 수 있습니다. 작업 기록의 복구 위치를 확인하세요.','Stopped after detecting an external change. An item may remain at a temporary name. Review recovery locations in History.','他のアプリによる変更を検出して停止しました。一時名の項目が残っている場合があります。履歴の復旧場所を確認してください。'],
'RecoveryObservedPaths':['발견된 위치입니다. 원본과 동일한 파일임을 확인하지 못해 자동 복원하지 않습니다.','Observed locations. Automatic restoration is blocked because the original identity could not be verified.','確認された場所です。元のファイルと同一であることを確認できないため自動復元しません。'],

'MoreActions':['추가 작업','More actions','その他の操作'],
'RestoreOriginal':['원래 이름 복원','Restore original names','元の名前に復元'],
'NoChangesExcluded':['선택한 항목이 변경되었거나 충돌하여 안전 검사에서 제외했습니다. 다시 검사한 뒤 상태와 경로를 확인하세요.','Selected items changed or conflict and were excluded by safety checks. Rescan and review their status and paths.','選択した項目が変更されたか競合したため除外しました。再検査して状態とパスを確認してください。'],
'OliveArchive':['올리브 아카이브','Olive Archive','オリーブアーカイブ'],

'About':['Moongchi NameFix 정보','About Moongchi NameFix','Moongchi NameFixについて'],
'EditMenu':['편집','Edit','編集'],
'MenuUndo':['실행 취소','Undo','取り消す'], 'MenuRedo':['다시 실행','Redo','やり直す'], 'MenuCut':['오려두기','Cut','カット'], 'MenuCopy':['복사','Copy','コピー'], 'MenuPaste':['붙여넣기','Paste','ペースト'], 'MenuSelectAll':['모두 선택','Select All','すべてを選択'], 'Services':['서비스','Services','サービス'],
'General':['일반','General','一般'], 'Appearance':['표시','Appearance','表示'],
'Privacy':['기록 및 개인정보','History and privacy','履歴とプライバシー'],
'Advanced':['문자 구성','Character details','文字の構成'],
'Graphemes':['글자 {0} · Unicode scalar {1} · UTF-16 {2}','Graphemes {0} · Unicode scalars {1} · UTF-16 {2}','文字 {0} · Unicode scalar {1} · UTF-16 {2}'],
'HistoryWarning':['일부 기록을 읽을 수 없습니다. 원본을 보존했으며 되돌리기는 제한됩니다.','Some records cannot be read. Originals are preserved; Undo is restricted.','一部の履歴を読み込めません。元の履歴を保持し、元に戻す操作を制限します。'],
'Recovery':['중단된 작업 복구 미리보기','Preview interrupted operation recovery','中断した操作の復旧を確認'],
'PlanExcluded':['안전 검사에서 제외: {0}개','Excluded by safety checks: {0}','安全確認で除外: {0}件'],
'PathColumn':['경로 열 표시','Show path column','パス列を表示'],
'None':['없음','None','なし'], 'Elapsed':['경과 {0}초','Elapsed {0}s','経過 {0}秒'],
'Quit':['Moongchi NameFix 종료','Quit Moongchi NameFix','Moongchi NameFixを終了'],
'FileMenu':['파일','File','ファイル'], 'ViewMenu':['보기','View','表示'],
'HelpMenu':['도움말','Help','ヘルプ'],
'FilterReset':['필터 초기화','Reset filters','絞り込み解除'],
'DiagnosticsPreview':['내보낼 진단 정보','Diagnostic export preview','出力する診断情報'],
'LocalOnly':['네트워크 통신 없이 이 Mac에서 처리합니다.','Processed on this Mac without network access.','ネットワーク通信を行わず、このMacで処理します。'],
'FilesystemHelp':['로컬 APFS 이름 변경을 지원합니다. 앱·링크·클라우드 및 확인되지 않은 볼륨은 보호합니다. 작업 중 다른 앱에서 같은 항목을 이동하거나 이름을 바꾸지 마세요.','Local APFS renaming is supported. Apps, links, cloud locations and unverified volumes are protected. Do not move or rename the same items in other apps during an operation.','ローカルAPFSに対応します。アプリ、リンク、クラウド、未確認のボリュームは保護します。処理中に他のアプリで同じ項目を移動・改名しないでください。'],
'AccessDenied':['× 접근 거부','× Access denied','× アクセス拒否'],
'InvalidPath':['안전하게 읽을 수 없는 경로입니다.','This path cannot be read safely.','安全に読み取れないパスです。'],
'ResultCancelled':['작업이 중단되었습니다. 완료된 변경은 기록에 보존됩니다.','Operation stopped. Completed changes are kept in History.','処理を停止しました。完了した変更は履歴に保存されます。'],
'ConfirmRecovery':['원래 이름으로 복원할 {0}개 항목을 확인하세요.','Review {0} items to restore to their original names.','元の名前に復元する{0}件を確認してください。'],
'HistoryRetentionHelp':['되돌리기와 복구에 필요한 기록은 설정한 개수를 넘어도 보존합니다.','Records needed for Undo and recovery are retained beyond this limit.','元に戻す操作や復旧に必要な履歴は上限を超えて保持します。'],
'Loading':['불러오는 중…','Loading…','読み込み中…'],
'License':['폰트 라이선스','Font licenses','フォントのライセンス'],
'InspectorHint':['목록에서 항목을 선택하세요.','Choose an item in the list.','一覧から項目を選択してください。'],
'CurrentSession':['현재 검사','Current scan','現在の検査'],
'DiagnosticsError':['진단 정보를 저장하지 못했습니다.','Could not save diagnostics.','診断情報を保存できませんでした。'],
'OpenHistoryFolder':['기록 폴더 보기','Show history folder','履歴フォルダーを表示'],
'Busy':['처리 중','Working','処理中'],
}
catalog.update(extra)
catalog.update(json.loads((root/"eng/expansion-localizations.json").read_text()))
resources=root/'Resources';resources.mkdir(exist_ok=True)
strings={key:{'extractionState':'manual','localizations':{lang:{'stringUnit':{'state':'translated','value':value}} for lang,value in zip(['ko','en','ja'],values)}} for key,values in catalog.items()}
(resources/'Localizable.xcstrings').write_text(json.dumps({'sourceLanguage':'en','strings':strings,'version':'1.0'},ensure_ascii=False,indent=2))
# xcstrings is the source of truth; generate runtime .strings for explicit in-app language selection.
for idx,lang in enumerate(['ko','en','ja']):
    d=resources/(lang+'.lproj');d.mkdir(exist_ok=True)
    (d/'Localizable.strings').write_text('\n'.join(json.dumps(k)+' = '+json.dumps(v[idx],ensure_ascii=False)+';' for k,v in sorted(catalog.items())))
    (d/'InfoPlist.strings').write_text('"Inspect Names with NameFix" = '+json.dumps(catalog['FinderServiceTitle'][idx],ensure_ascii=False)+';\n')
for f in (handoff/'assets/fonts').iterdir(): shutil.copy2(f,resources/f.name)
print(len(catalog),'keys, three locales')
