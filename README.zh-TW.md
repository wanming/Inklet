# Inklet

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [Italiano](README.it.md)

官方網站：[getinklet.app](https://getinklet.app)

**Turn rough thoughts into clear text.**

**Inklet** 是一款 macOS 寫作助手，可以把你輸入、貼上或說出的想法整理成清楚自然的文字，並直接插回正在使用的 App。

你可以用全域快速鍵打開寫作浮窗，然後在同一份可編輯的原文草稿中輸入、貼上或聽寫。即時聽寫已整合進寫作助手，轉寫完成後會留在草稿裡，等你檢查和編輯後再決定要轉換或插入。在 Apple 晶片的 Mac 上，新安裝預設在本機辨識語音，聲音不會離開這台 Mac。

> 本文件由英文版 [README.md](README.md) 翻譯而來。若兩者有出入，請以英文版為準。

## 安裝

GitHub Releases 是 Inklet 唯一支援的發布管道。請從 [GitHub Releases](https://github.com/wanming/Inklet/releases) 下載最新且已簽署並通過 Apple 公證的 DMG，打開後把 Inklet 拷貝到 `/Applications`。

也可以使用下面的安裝指令碼。它會下載最新的 GitHub Releases DMG 及 checksum，驗證 DMG 結構、checksum、Gatekeeper、bundle identifier、Hardened Runtime、effective entitlements 與 App 簽章，再把 Inklet 拷貝到 `/Applications`。

```bash
curl -fsSL https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | bash
```

## 更新

Inklet 只透過 GitHub Releases 檢查更新。正式版大約每 24 小時向 GitHub 取得一次最新穩定版的公開中繼資料。只有在該 release 已上傳 `Inklet.dmg` 後才會提示更新；選擇**在 GitHub 上查看**會打開那個 release 的頁面。Inklet 不會自動下載或安裝更新。

正式版和 Inklet Local 都可以從 App 選單選擇**檢查更新…**手動檢查；Inklet Local 不會排程自動檢查。自動檢查失敗時不會打擾你，手動檢查失敗時可以選擇**重試**。當寫作、聽寫、選取動作、資料移轉、強制回應視窗或已打開的選單讓 Inklet 處於忙碌狀態時，自動更新通知會等到 App 閒置後才顯示。

更新後第一次打開新版本時，Inklet 會在閒置時顯示一次簡短的**新功能**視窗，而且不會搶走你正在使用的 App 的焦點。新安裝或歡迎導覽打開時不會出現。選單列選單中的**更新日誌**會列出所有版本，並標示你正在使用的版本。

## 首次設定

1. 從「應用程式」檔案夾打開 Inklet。若要執行原始碼建置版本，請在儲存庫根目錄執行 `scripts/run-local-app.sh`，然後使用 `/Applications/Inklet Local.app`。
2. 按一下選單列上的 Inklet 圖像，打開**設定**。
3. 依 macOS 提示授予「輔助使用」權限。Inklet 只用這一個通用權限來讀取選取的文字、執行已設定的拷貝備援流程、回到上一個 App，並貼上確認過的結果。「系統設定」打開期間 Inklet 會留在背景；關閉後會回到**一般**設定頁。
4. 新安裝時，以及從舊版更新到這個版本後的第一次啟動，會出現歡迎導覽，一步步設定介面語言（新安裝預設跟隨系統語言）、輔助使用權限、寫作模型、即時聽寫用的麥克風，以及打開 Inklet 和聽寫的快速鍵，最後介紹選取文字後出現的工具列。想再看一遍時，在選單列選單中選擇**新手引導**，每一步都從你目前的設定開始。在 Apple 晶片的 Mac 上，導覽會建議使用**內建**與推薦的模型，保留這個選項後會在背景下載；寫作浮窗會顯示下載進度，下載完成後離線也能使用。若想改用雲端服務商，請在**AI 模型**中選擇服務商並輸入它的 API key。Intel Mac 預設使用 OpenAI，一把 key 就能處理寫作、即時聽寫、選取翻譯和發音。選擇其他服務商時，寫作和選取翻譯使用該服務商；發音，以及選擇 OpenAI 辨識時的聽寫，仍需要在同一頁的 API 金鑰卡片中輸入 OpenAI API key。若想在本機執行寫作和翻譯、完全不需要 key，可以選擇**內建**並下載一個模型；如果你已經在使用 Ollama 或 LM Studio，也可以直接選擇它們（見[本機模型](#本機模型)）。
5. 在**寫作助手**中設定模型、寫作快速鍵、生成參數和 Prompt 模式。**即時聽寫**有自己的設定頁：可以開啟或關閉、選擇用**本機**或 **OpenAI** 進行語音辨識，並選擇長按快速鍵和麥克風。在 Apple 晶片的 Mac 上，新安裝預設使用**本機**，在歡迎導覽中開啟聽寫時會下載語音模型；既有的設定會繼續使用 OpenAI，直到你手動切換。使用 OpenAI 時，**進階聽寫**只提供復原模型，復原端點無法編輯。即時轉寫模型由 Inklet 固定。
6. 選用：在**選區助手**中設定翻譯語言、**強制取詞**模式、AI 發音的聲音和速度，並可在設定中試聽聲音。
7. 第一次有效長按聽寫快速鍵時，授予「麥克風」權限。只是打開 Inklet、查看設定，或在原文編輯器以外按下快速鍵，都不會要求權限。

## 日常使用

文字流程：

1. 在任何 App 中把焦點放到一個文字欄位。
2. 按 `Option+Space`。
3. 用模糊搜尋找到 Prompt 模式（例如 `英文` 可以比對到 `改寫成簡單正確的英文`），用 `↑` / `↓` 標示，然後按 `Tab` 或 `Enter` 確認模式。
4. 輸入或貼上一段草稿。
5. 按 `Enter` 進行轉換。結果會邊生成邊顯示；按 `Escape` 可以停止。
6. 再按一次 `Enter` 插入結果，或按 `Shift+Command+C`（也可以按一下結果上的拷貝按鈕）改為拷貝。

聽寫流程：

1. 用 `Option+Space` **打開寫作助手**。
2. **確認一個 Prompt 模式**。在模式選擇器和結果編輯器中無法聽寫。
3. **把游標放進原文草稿，或選取要取代的文字。** 聽寫會插入在游標處，或取代選取的文字。
4. **長按已設定的聽寫快速鍵**（預設是右側 Option）並正常說話，草稿會即時更新。短按不會執行任何動作。如果即時連線中斷，請繼續按住並說話，Inklet 會保留一份暫存的復原錄音。
5. **放開以完成轉寫**。使用**本機**辨識時，復原錄音也在本機轉寫。使用 OpenAI 時，若需要復原，Inklet 會使用即時聽寫所用的同一把 OpenAI API key，只向 `https://api.openai.com/v1/audio/transcriptions` 送出一次請求。暫存錄音在備援請求真正開始前都只留在本機，最多上傳一次，並在聽寫結束時刪除。
6. 檢查並編輯聽寫草稿。聽寫本身不會執行 Prompt 模式，也不會把文字插入其他 App。
7. **準備好再按 Return** 執行已確認的 Prompt 模式；只有想插入結果時才再按一次 Return。

聽寫快速鍵只在原文編輯器中有效，而且只支援長按。你可以在**設定** → **即時聽寫**中把修飾鍵改為右側 Command、左側 Option 或左側 Command，或完全關閉聽寫。按 Escape、失去焦點、關閉浮窗或開始新的原文工作階段，都會取消聽寫並還原原本的草稿。

## 功能

- 以全域 macOS 快速鍵打開，預設是 `Option+Space`。
- 寫作助手的原文編輯器處於使用中時，長按修飾鍵快速鍵即可把即時聽寫寫進草稿，預設是右側 Option。
- 在其他 Mac App 中選取文字並稍作停頓後，會顯示選取動作，提供 EasyDict 風格的取詞、快速翻譯、可自訂的「翻譯」prompt 和 AI 發音；翻譯結果視窗可調整大小並記住上次的尺寸，重複的翻譯會在本機快取 7 天。
- 選取選單或翻譯結果擋住內容時，可以把它拖到任意位置；按一下按鈕不受影響，下一次選取文字時會重新出現在文字旁邊。
- 會忽略超過 1,500 個字元的選取文字，避免不小心選到整頁時觸發。
- 可以直接播放選取的文字，也可以在翻譯結果中分別播放原文和譯文。
- 可以在**設定** › **選區助手** › **選單按鈕**中選擇選取選單要顯示哪些按鈕及其順序。**翻譯**、**發音**和任何 Prompt 模式都可以作為按鈕；最多同時顯示四個，其餘放在**更多**裡。按下 Prompt 模式按鈕會用該模式處理選取的文字，並在面板中顯示結果，可拷貝和播放。
- 內建的文字轉換 Prompt 模式：
  - To Simple and Correct English（目標是你的寫作語言，在設定 › 一般裡選擇，預設英文）
  - Summarize（輸出為你的翻譯語言，預設跟隨介面語言）
  - To Traditional Chinese 等（翻譯成你的翻譯語言；如果只選了一個單字，會顯示意思、發音和例句）
  - Voice Cleanup
  - 內建模式的名稱在任何介面語言下都維持英文，方便用同樣的字母搜尋；改名之前，名稱裡的語言會跟隨你的設定。
- 結果邊生成邊顯示在浮窗中，完成後可以插回先前有焦點的 App，或用結果上的拷貝按鈕拷貝。
- 使用與 App 無關、以「輔助使用」為優先的通用取詞流程。自動選取動作會先透過 macOS 輔助使用讀取選取內容，只有在**強制取詞**允許時，才會使用已設定的暫存剪貼簿備援。每次讀取都綁定在擷取到的來源程序上；來源程序結束或失去焦點時就會取消。
- 預設關閉模擬 `Command+C`。選單拷貝仍是安全的**強制取詞**備援方式；對於沒有可用「拷貝」選單的 App，你可以明確開啟模擬拷貝作為進階備援，但它可能干擾遊戲、遠端桌面或虛擬機器。
- 暫存剪貼簿讀取會依序執行。只有同一次讀取仍持有觀察到的拷貝結果時，Inklet 才會還原先前的快照；較新的剪貼簿內容優先。連按兩次拷貝的觸發方式是被動的：它只讀取你已經完成的拷貝，不會再送出一次合成拷貝，也不會還原較舊的剪貼簿資料。按右鍵維持原生行為，不會開始取詞。
- 不使用任何瀏覽器專屬的取詞程式碼，也不會要求瀏覽器「自動化」權限。Chrome、Safari、Edge 和原生 App 都使用同一條通用流程。
- 可以編輯 Prompt 模式、服務商、模型、自訂 OpenAI 相容端點、逾時、寫作快速鍵、聽寫長按快速鍵、麥克風、復原模型、選取翻譯語言、選取「翻譯」prompt、選單按鈕、**強制取詞**模式、模擬拷貝權限、AI 發音聲音和 AI 發音速度。
- 在本機**歷史**中查看成功的寫作和選取結果，連續重複的項目會自動合併，原文和結果文字都可以選取，並提供結果拷貝與全部清除功能。舊版的 Voice 項目仍可讀取。
- 寫作和翻譯可以使用 OpenAI、Anthropic、Google Gemini、DeepSeek、阿里通義千問（Alibaba Qwen）、月之暗面 Kimi、智譜 GLM、MiniMax、矽基流動（SiliconFlow）、火山方舟（Volcengine Ark）、騰訊混元、百川、零一萬物 Yi、xAI、Groq、Mistral、OpenRouter、Perplexity、Together AI、Cerebras，或任何自訂的 OpenAI 相容端點（例如本機模型伺服器）。發音一律使用 OpenAI；聽寫使用**即時聽寫**中選擇的語音辨識引擎。
- 寫作和翻譯可以在你的 Mac 上執行：使用內建引擎（Qwen3.5 4B 或 Gemma 4 E4B，從 Hugging Face 下載一次），或連接本機的 Ollama、LM Studio 伺服器。不需要 API key，文字也不會離開你的 Mac。
- 提供英文、簡體中文、繁體中文、日文、韓文、西班牙文、法文、德文、葡萄牙文和義大利文的 App 介面。
- 精簡的選取選單以及設定和寫作介面中空間有限的控制項，會依翻譯後的標籤調整版面；切換語言時會更新已打開的介面，並保留寫作內容。

## 目前狀態

Inklet 是早期的 MVP。目前儲存庫包含：

- macOS App 與核心寫作引擎的 Swift Package。
- 具備寫作浮窗和設定視窗的選單列 App。
- 服務商轉接器與設定儲存。
- 核心行為的單元測試。
- 手動測試說明：[docs/manual-test-checklist.md](docs/manual-test-checklist.md)。

## 系統需求

- macOS 14 或更新版本。
- Swift 6 toolchain。
- 建議安裝完整的 Xcode，以取得 XCTest 支援。
- Inklet 的「輔助使用」權限，用於通用取詞、已設定的拷貝備援、回到上一個 App，以及貼上生成的結果。
- 「麥克風」權限，只在長按快速鍵進行即時聽寫時使用。
- OpenAI 或其他支援服務商的 API key，或使用本機模型。發音，以及使用 OpenAI 引擎的聽寫，需要 OpenAI API key。

## 本機模型

Inklet 可以用在你 Mac 上執行的模型來寫作和翻譯，文字不會離開這台 Mac，也不需要 API key。

- **內建**（僅限 Apple 晶片，新安裝的預設選項）：服務商選擇**內建**，挑一個模型，然後按**下載**。記憶體 16 GB 以上的 Mac 預設使用 Gemma 4 E4B（約 4.6 GB）；8 GB 的 Mac 建議使用 Qwen3.5 4B（約 2.7 GB）。新安裝時由歡迎導覽下載；模型下載期間，寫作浮窗會顯示進度，若模型還沒下載，浮窗裡也會有**下載**按鈕。下載中斷後可以續傳，使用前會以固定的 SHA-256 驗證。選擇內建時，打開寫作浮窗後 Inklet 會在回送位址（loopback）上啟動內建的 llama.cpp 伺服器並載入模型，通常你送出文字時模型已經準備好了。記憶體 24 GB 以上的 Mac 會讓模型常駐，只在 macOS 記憶體不足時釋放；記憶體較小的 Mac 會在閒置五分鐘後釋放。
- **本機聽寫**（僅限 Apple 晶片，新安裝的預設選項）：即時聽寫使用 Qwen3-ASR 0.6B（約 1 GB）辨識語音，支援 30 種語言以及中英夾雜。它在同一個內建 llama.cpp 引擎上以獨立的伺服器執行，說話時大約每 0.6 秒重新轉寫一次，並在停頓處把句子定稿。記憶體 16 GB 以上的 Mac 會在聽寫開啟期間讓語音模型常駐；記憶體較小的 Mac 會在打開寫作浮窗時載入，閒置五分鐘後釋放。關閉聽寫或改用 OpenAI 就會停止它。當 Inklet 或 macOS 使用繁體中文時，聽寫出的中文會以繁體字呈現。
- **Ollama**：安裝 [Ollama](https://ollama.com)，執行 `ollama pull qwen3.5:4b`，然後選擇 **Ollama**。Inklet 會列出 Ollama 已下載的模型。
- **LM Studio**：在連接埠 1234 啟動 LM Studio 的本機伺服器並載入模型，然後選擇 **LM Studio**。

本機服務商的每次請求至少有 120 秒，讓第一次請求有時間載入模型。Inklet 會要求本機伺服器略過「思考」，讓小型推理模型直接回答。原始碼建置會透過 `scripts/build-llama-server.sh` 編譯內建引擎，需要 `cmake`；如果沒有安裝，App 仍可執行，**內建**選項會說明這個版本未包含引擎。

## 從原始碼建置與執行

每次建置 App bundle 前，都要遞增根目錄 `VERSION` 檔案中的 `INKLET_VERSION` 和 `INKLET_BUILD_NUMBER`。通常遞增修補版本；較大的變更使用次版本或主版本。建置編號必須是大於所有已用過建置編號的正整數，即使行銷版本改變也不能重設。選擇建置編號前，請檢查最新的 `main`、Git tags、所有 GitHub releases（包括草稿）以及使用中的 worktrees。Inklet 只依建置編號判斷是否有更新。

遠端 GitHub DMG 建置只從 `main` 執行。請先把預定的變更和更新後的 `VERSION` 合併並推送到 `main`，再以 `--ref main` 觸發 `build-dmg.yml`。

正式發布前，請確認建置成功並驗證最終產物，把預留的說明替換成相較上一個正式穩定版的中英文更新內容，再發布為最新穩定版。已驗證的草稿可以直接發布，不需要重新建置或修改版本。

DMG 工作流程會在建置前檢查並拒絕重複或較小的建置編號，但不會自動遞增這兩個值。手動驗證方法見[發布版本檢查](scripts/README.md#release-version-checks)。修改已封裝 App 的版本需要重新建置、簽署、公證並重新產生 checksum；只修改 release 標題或檔名不會更新 App。

在儲存庫根目錄執行：

```bash
swift build
scripts/run-local-app.sh
```

日常手動測試請從任何 worktree 使用 `scripts/run-local-app.sh`。它會安裝並打開固定的 `/Applications/Inklet Local.app` 身分，讓 macOS 的輔助使用與鑰匙圈授權可以在重新建置之間沿用。

執行測試：

```bash
swift test
```

如果測試因為 `XCTest` 無法使用而失敗，請安裝完整的 Xcode，而不是只安裝 Command Line Tools。

使用 `scripts/check-localization.sh` 檢查所有介面語言。加上 `--snapshots` 會在 `.build/localization-audit/` 下產生以模擬資料呈現原生介面的 HTML 圖庫，指令會輸出它的路徑。Pull request 和推送到 `main` 的提交會自動執行完整的單元測試和在地化檢查。檢查範圍與仍需手動確認的項目見[在地化檢查說明](docs/localization-audit.md)。

## 快速鍵

- `Option+Space`：打開寫作浮窗。
- `Right Option`：寫作助手的原文編輯器處於使用中時，長按以聽寫。可在**設定** → **即時聽寫**中更改修飾鍵或關閉聽寫；短按不會有任何作用。
- 模式啟動器中的 `↑` / `↓`：在依模糊比對排序的 Prompt 模式間移動標示。
- 模式啟動器中的 `Tab`、`Return` 或數字鍵盤 `Enter`：確認標示的 Prompt 模式並把焦點移到原文編輯器。輸入法正在組字時，Return 仍用於確認文字或候選字；搭配 Command、Shift、Option 或 Control 的 Return 不會確認模式。
- 編輯器中的 `Enter`：轉換原文、插入目前模式產生的結果，或用剛確認的新模式重新生成由先前模式產生的舊結果。
- `Command+Enter`：不呼叫模型，直接插入原文。
- `Shift+Command+C`：拷貝目前的結果，浮窗保持打開。
- `Command+Up` / `Command+Down`：切換可見的 Prompt 模式。
- 單獨按住 `Command`：在底欄顯示所有快捷鍵。平時底欄只顯示聽寫提示和主按鈕，所有快捷鍵都照常可用。
- `Escape`：每按一次退回一層，依序從結果回到原文編輯器、模式啟動器，再關閉浮窗。轉換期間按下會停止生成、捨棄未完成的結果，並留在編輯器。
- `Command+,`：Inklet 在前景時打開設定。

搜尋不區分大小寫和變音符號，並支援依序比對字元。完全符合和前綴符合的權重最高；連續、字首、位置較前以及間隔較緊密的符合，通常排序較高。

模式啟動器打開時，如果上次確認的 Prompt 模式仍然可見，就會標示該模式。按一下只會標示模式，按兩下才會確認；回到模式啟動器時會保留目前的草稿和結果。

## 儲存庫結構

```text
Sources/InkletApp/       macOS app, popover UI, settings UI, menu bar coordination
Sources/InkletCore/      core config, providers, prompts, hotkeys, insertion, state machine
Tests/InkletCoreTests/   unit tests for core behavior
docs/                    手動測試說明與隱私權政策
```

## 開發說明

- 服務商行為應有聚焦的單元測試涵蓋。
- 發布使用者可見的 App 變更前，請使用 [docs/manual-test-checklist.md](docs/manual-test-checklist.md)。
- 日常手動測試 App 時請使用 `scripts/run-local-app.sh`，不要直接執行 SwiftPM 執行檔或 `open dist/...`，這樣本機的輔助使用與鑰匙圈授權才會綁定在同一個固定的 App 身分上。
- 剪貼簿和輔助使用流程是核心體驗，請謹慎處理。
- 專案仍在 MVP 階段，README 應描述目前程式碼已支援的功能，而不是未來的計畫。

## 本機儲存與升級

正式版與本機 QA 版使用依 bundle 識別碼區隔的儲存空間，不共用設定、歷史、翻譯快取、診斷資料或鑰匙圈憑證：

- 正式版 Application Support：`~/Library/Application Support/com.tomwan.inklet/`
- 本機版 Application Support：`~/Library/Application Support/com.tomwan.inklet.local/`
- 正式版偏好設定：`~/Library/Preferences/com.tomwan.inklet.plist`
- 本機版偏好設定：`~/Library/Preferences/com.tomwan.inklet.local.plist`
- 服務商 API key：對應 Application Support 檔案夾中的 `api-keys.json`，只有你的使用者帳號能讀取，且不會納入 Time Machine 備份
- 舊版本使用的鑰匙圈服務：`Inklet.ProviderAPIKey`（正式版）和 `Inklet.Local.ProviderAPIKey`（本機版）

舊版本把 API key 存在鑰匙圈中。第一次需要某把 key 時，Inklet 會把它從鑰匙圈拷貝到 `api-keys.json`，並保留鑰匙圈中的項目，因此退回舊版本時仍然找得到。在設定中修改或清除 key 時，會一併移除鑰匙圈中的副本。

從舊版沙盒建置升級後的第一次啟動時，Inklet 會自動拷貝可辨識的舊版偏好設定、把服務商 API key 寫入對應的鑰匙圈服務，並把歷史拷貝到目前 bundle 的儲存空間。它不會刪除或修改舊版來源，所以舊資料仍可用於回復或救援。可捨棄的翻譯快取不會移轉。

如果 macOS 阻擋自動存取對應的舊版容器，設定中會一直提供**匯入舊資料…**動作。輔助匯入只接受目前正式版或本機版所對應的那個舊版 `Data` 檔案夾，只在目前的檔案面板授權有效期間讀取，且不會保存永久的存取書籤。

## 隱私權

- Inklet 會用你在設定中選擇的服務商及其 API key 處理寫作和選取翻譯。發音一律使用你的 OpenAI API key 與 OpenAI。只有在把 OpenAI 選為語音辨識引擎時，聽寫才會使用 OpenAI。
- 使用**本機**語音辨識時，聽寫音訊和它的復原錄音都由你 Mac 上的伺服器處理，不會離開這台 Mac。
- 使用 OpenAI 語音辨識時，長按聽寫快速鍵期間，使用中的麥克風音訊會直接串流到 OpenAI Realtime 轉寫服務。Inklet 也會保留一份暫存的本機復原錄音；它在備援請求真正開始前都只留在本機，最多上傳一次到 `https://api.openai.com/v1/audio/transcriptions`，使用即時聽寫所用的同一把 OpenAI API key，並在每一種工作階段結束路徑中刪除。
- 你的 API key 依服務商分別儲存在你的 Mac 上。
- 使用內建、Ollama 或 LM Studio 時，寫作和翻譯請求只會送到你 Mac 上的伺服器。下載內建模型時，會向 Hugging Face 請求一次所選的檔案；請求中不包含你的文字、音訊、API key 或設定。
- Inklet 使用「輔助使用」權限進行通用取詞、已設定的拷貝備援、回到上一個 App，以及貼上文字。
- Inklet 只在寫作助手原文編輯器中有效長按聽寫快速鍵時使用「麥克風」權限。聽寫完成後會留下可編輯的草稿，不會插入其他 App。
- Inklet 會暫時使用剪貼簿完成插入和已設定的**強制取詞**備援讀取。強制取詞只在 Inklet 暫時拷貝的內容仍是目前內容時才還原原本的剪貼簿，不會覆蓋之後發生的外部剪貼簿變更。
- Inklet 會把成功的寫作和選取原文與結果儲存在本機**歷史**中，直到你在設定中清除；連續重複的項目會略過。尚未處理的聽寫草稿不會建立歷史項目；既有的舊版 Voice 項目仍可在本機讀取。
- 選取動作會擷取來源 App 和選取位置，在讀取前和讀取期間驗證來源，並透過輔助使用讀取它目前的選取內容。如果輔助使用沒有回傳選取的文字，已設定的**強制取詞**模式可以短暫呼叫選單拷貝，並透過上述受保護的流程讀取拷貝出的剪貼簿文字。模擬 `Command+C` 預設關閉，只有在明確開啟進階選項後才會執行。你可以在設定中關閉**強制取詞**。這條流程不會送出針對瀏覽器的 Apple Events，也不會要求瀏覽器「自動化」權限。選取文字後快速按兩次 `Command+C`，會明確讀取你已經完成的拷貝。只是選取的文字不會被儲存，除非有成功的動作被記錄到本機歷史中。
- 選區助手會用雜湊快取鍵把成功的翻譯結果在本機快取 7 天，加快重複翻譯的速度。
- 本機沒有可用快取時，選區助手的翻譯會把選取的文字和你自訂的「翻譯」指示送到你選擇的服務商；Prompt 模式按鈕會把選取的文字和該模式的 prompt 送到你選擇的服務商；AI 發音會把選取的文字送到 OpenAI。
- Inklet 每天最多從 `models.dev` 取得一次公開的模型目錄。這個請求不包含你的文字、音訊、API key 或 App 設定。
- 除非你信任 OpenAI 或所選服務商的資料處理政策，否則請不要送出私密的文字或音訊。

## 意見回饋

在 Inklet 選單列選單中選擇**傳送意見回饋…**，或[開一個 issue](https://github.com/wanming/Inklet/issues/new/choose)。歡迎回報問題和提出功能建議；請不要在 issue 中貼上 API key 或私密文字。

## 貢獻

請參閱 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 安全性

漏洞回報與敏感資料相關說明請參閱 [SECURITY.md](SECURITY.md)。

## 授權條款

Inklet 以 [MIT License](LICENSE) 發布。
第三方授權聲明列於 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
