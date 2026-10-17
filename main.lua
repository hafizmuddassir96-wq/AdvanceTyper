require "import"
import "android.widget.*"
import "android.view.*"
import "android.content.Intent"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognitionListener"
import "android.speech.RecognizerIntent"
import "android.content.Context"
import "android.os.Handler"
import "android.os.Looper"
import "com.androlua.Http"
import "cjson"
import "android.content.ClipData"
import "android.content.ClipboardManager"
import "java.lang.System"
import "android.net.Uri"
import "android.text.TextWatcher"
import "android.os.Bundle"
import "android.view.accessibility.AccessibilityNodeInfo"
import "java.io.*"

-- Auto Update Configuration
local CURRENT_VERSION = "2.3"
local VERSION_URL = "https://raw.githubusercontent.com/hafizmuddassir96-wq/AdvanceTyper/main/werjan.txt"
local UPDATE_CODE_URL = "https://raw.githubusercontent.com/hafizmuddassir96-wq/AdvanceTyper/main/main.lua"
local PLUGIN_PATH = "/storage/emulated/0/解说/Plugins/Advance Typer/main.lua"
local updateInProgress = false
local mainHandler = Handler(Looper.getMainLooper())
local Runnable = luajava.bindClass("java.lang.Runnable")

local active_dialogs = {}

local function registerDialog(dlg)
  table.insert(active_dialogs, dlg)
end

local function unregisterDialog(dlg)
  for i, d in ipairs(active_dialogs) do
    if d == dlg then
      table.remove(active_dialogs, i)
      break
    end
  end
end

local function dismissAllDialogs()
  for _, d in ipairs(active_dialogs) do
    pcall(function() d.dismiss() end)
  end
  active_dialogs = {}
end

local function trim(s)
    if s == nil then return "" end
    return tostring(s):gsub("^%s*(.-)%s*$", "%1")
end

local function showUpdateErrorDialog(title, message)
    mainHandler.post(Runnable({
        run = function()
            local errorDialog = LuaDialog()
            errorDialog.setTitle(title)
            errorDialog.setMessage(message)
            errorDialog.setPositiveButton("OK", function()
                errorDialog.dismiss()
            end)
            errorDialog.show()
        end
    }))
end

local function performUpdate(mainCode, onlineVersion)
    if not mainCode or trim(mainCode) == "" then
        showUpdateErrorDialog("Update Failed", "Main plugin code is empty.")
        return
    end
    
    updateInProgress = true
    
    local function updateProcess()
        local success = false
        local tempPath = PLUGIN_PATH .. ".temp_update"
        local f = io.open(tempPath, "w")
        if f then
            f:write(mainCode)
            f:close()
            
            local fileExists = io.open(PLUGIN_PATH, "r")
            if fileExists then
                fileExists:close()
                local delSuccess = pcall(function()
                    os.remove(PLUGIN_PATH)
                end)
                if delSuccess then
                    local renameSuccess = pcall(function()
                        os.rename(tempPath, PLUGIN_PATH)
                    end)
                    if renameSuccess then
                        success = true
                    end
                end
            else
                local renameSuccess = pcall(function()
                    os.rename(tempPath, PLUGIN_PATH)
                end)
                if renameSuccess then
                    success = true
                end
            end
            
            if not success then
                pcall(function() os.remove(tempPath) end)
            end
        end
        
        if success then
            updateInProgress = false
            mainHandler.post(Runnable({
                run = function()
                    service.speak("Plugin successfully updated to version " .. onlineVersion .. ". Plugin will restart automatically.")
                    local successDialog = LuaDialog()
                    successDialog.setTitle("Update Successful")
                    successDialog.setMessage("Plugin successfully updated to version " .. onlineVersion .. ".\n\nPlugin will restart automatically.")
                    successDialog.setPositiveButton("OK", function()
                        successDialog.dismiss()
                        dismissAllDialogs()
                        mainHandler.postDelayed(Runnable({
                            run = function()
                                local pluginFile = io.open(PLUGIN_PATH, "r")
                                if pluginFile then
                                    pluginFile:close()
                                    local func, err = loadfile(PLUGIN_PATH)
                                    if func then
                                        pcall(func)
                                    else
                                        Toast.makeText(service, "Error reloading plugin: " .. tostring(err), Toast.LENGTH_SHORT).show()
                                    end
                                end
                            end
                        }), 2000)
                    end)
                    successDialog.show()
                end
            }))
            return
        else
            updateInProgress = false
            showUpdateErrorDialog("Update Failed", "Update failed. Please try again.")
        end
    end
    
    local updateThread = Thread(Runnable{
        run = updateProcess
    })
    updateThread.start()
end

local function checkUpdate(isManual)
    if updateInProgress then
        return
    end
    
    if isManual then
        mainHandler.post(Runnable({
            run = function()
                Toast.makeText(service, "Checking for updates...", Toast.LENGTH_SHORT).show()
                service.speak("Checking for updates")
            end
        }))
    end
    
    local timestamp = tostring(os.time())
    Http.get(VERSION_URL .. "?t=" .. timestamp, function(code, response)
        if code == 200 and response then
            local onlineVersion = trim(response)
            if onlineVersion ~= CURRENT_VERSION then
                Http.get(UPDATE_CODE_URL .. "?t=" .. timestamp, function(code2, mainCode)
                    if code2 == 200 and mainCode and trim(mainCode) ~= "" then
                        mainHandler.post(Runnable({
                            run = function()
                                service.speak("A new version " .. onlineVersion .. " is available. Would you like to update now?")
                                local updateAlertDlg = LuaDialog()
                                updateAlertDlg.setTitle("Update Available!")
                                updateAlertDlg.setMessage("A new version (" .. onlineVersion .. ") is available.\nCurrent version: " .. CURRENT_VERSION .. "\n\nWould you like to update now?")
                                updateAlertDlg.setPositiveButton("Update Now", function()
                                    updateAlertDlg.dismiss()
                                    performUpdate(mainCode, onlineVersion)
                                end)
                                updateAlertDlg.setNegativeButton("Later", function()
                                    updateAlertDlg.dismiss()
                                end)
                                updateAlertDlg.show()
                            end
                        }))
                    else
                        if isManual then
                            mainHandler.post(Runnable({
                                run = function()
                                    Toast.makeText(service, "Failed to download update code.", Toast.LENGTH_SHORT).show()
                                    service.speak("Failed to download update code")
                                end
                            }))
                        end
                    end
                end)
            else
                if isManual then
                    mainHandler.post(Runnable({
                        run = function()
                            Toast.makeText(service, "You are using the latest version (" .. CURRENT_VERSION .. ").", Toast.LENGTH_SHORT).show()
                            service.speak("You are using the latest version")
                        end
                    }))
                end
            end
        else
            if isManual then
                mainHandler.post(Runnable({
                    run = function()
                        Toast.makeText(service, "Failed to check for updates. Check internet connection.", Toast.LENGTH_SHORT).show()
                        service.speak("Failed to check for updates")
                    end
                }))
            end
        end
    end)
end

local AI_PREFS = "UniqueTyperAI_Saifi"
local aiPrefs = service.getSharedPreferences(AI_PREFS, Context.MODE_PRIVATE)
local aiEditor = aiPrefs.edit()

local function escapePattern(str)
  return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function getDictionary()
  local jsonStr = aiPrefs.getString("user_dictionary", "{}")
  local ok, dict = pcall(cjson.decode, jsonStr)
  return (ok and type(dict) == "table") and dict or {}
end

local function saveDictionary(dict)
  aiEditor.putString("user_dictionary", cjson.encode(dict))
  aiEditor.apply()
end

local function applyDictionary(text)
  local dict = getDictionary()
  if not text or text == "" or not next(dict) then return text end

  local padded = " " .. text .. " "
  for wrong, correct in pairs(dict) do
    if wrong and wrong ~= "" and correct then
      local ew = escapePattern(wrong)
      padded = padded:gsub("([%s%p])" .. ew .. "([%s%p])", "%1" .. correct .. "%2")
    end
  end
  return padded:sub(2, -2)
end

local function getEmojiLevel()
  return aiPrefs.getString("emoji_level", "Medium")
end

local function setEmojiLevel(level)
  aiEditor.putString("emoji_level", level)
  aiEditor.apply()
end

local function isTranslationEnabled()
  return aiPrefs.getBoolean("transEnabled", false)
end

local function setTranslationEnabled(enabled)
  aiEditor.putBoolean("transEnabled", enabled)
  aiEditor.apply()
end

local function getWritingStyle()
  return aiPrefs.getString("ai_style", "Casual")
end

local function setWritingStyle(style)
  aiEditor.putString("ai_style", style)
  aiEditor.apply()
end

local function getCustomPrompt()
  return aiPrefs.getString("ai_custom_prompt", "")
end

local function setCustomPrompt(prompt)
  aiEditor.putString("ai_custom_prompt", prompt)
  aiEditor.apply()
end

local function getSelectedModel()
  return aiPrefs.getString("ai_model", "gemini-1.5-flash")
end

local function setSelectedModel(modelName)
  aiEditor.putString("ai_model", modelName)
  aiEditor.apply()
end

local function getDefaultLanguage()
  return aiPrefs.getString("default_typing_lang", "Manual Select")
end

local function setDefaultLanguage(lang)
  aiEditor.putString("default_typing_lang", lang)
  aiEditor.apply()
end

local function getGeminiApiKey()
  return aiPrefs.getString("gemini_apiKey", "")
end

local function saveGeminiApiKey(key)
  aiEditor.putString("gemini_apiKey", key)
  aiEditor.apply()
end

local function getModelDisplayName(cleanName)
  local desc = "ٹیکسٹ اور وائس ٹائپنگ کے لیے موزوں ماڈل"
  if cleanName:find("flash%-lite") then
    desc = "کوئیک میسجز کے لیے انتہائی ہلکا اور فاسٹ ماڈل"
  elseif cleanName:find("flash") then
    desc = "روزمرہ کی فاسٹ وائس ٹائپنگ کے لیے تیز ترین ماڈل"
  elseif cleanName:find("pro") then
    desc = "زیادہ ذہین، گرامر اور بہترین ٹیکسٹ ایڈیٹنگ ماڈل"
  end
  return cleanName .. " (" .. desc .. ")"
end

local function getAITextsList()
  local jsonStr = aiPrefs.getString("ai_texts_list", "[]")
  local ok, list = pcall(cjson.decode, jsonStr)
  if not (ok and type(list) == "table") then return {} end
  
  local currentTime = os.time()
  local validList = {}
  local changed = false
  
  for _, item in ipairs(list) do
    if type(item) == "table" and item.text and item.time then
      if (currentTime - item.time) <= 3600 then
        table.insert(validList, item)
      else
        changed = true
      end
    end
  end
  
  if changed then
    aiEditor.putString("ai_texts_list", cjson.encode(validList))
    aiEditor.apply()
  end
  
  local result = {}
  for _, item in ipairs(validList) do
    table.insert(result, item.text)
  end
  return result
end

local function saveAIText(text)
  local jsonStr = aiPrefs.getString("ai_texts_list", "[]")
  local ok, list = pcall(cjson.decode, jsonStr)
  if not (ok and type(list) == "table") then list = {} end
  
  local currentTime = os.time()
  local validList = {}
  
  for _, item in ipairs(list) do
    if type(item) == "table" and item.text and item.time then
      if (currentTime - item.time) <= 3600 then
        table.insert(validList, item)
      end
    end
  end
  
  table.insert(validList, 1, {text = text, time = currentTime})
  if #validList > 5 then
    table.remove(validList, 6)
  end
  
  aiEditor.putString("ai_texts_list", cjson.encode(validList))
  aiEditor.apply()
end

local function speakDelayed(text)
  Handler(Looper.getMainLooper()).postDelayed(Runnable{
    run = function()
      service.speak(text)
    end
  }, 600)
end

local function callGeminiAPI(apiKey, modelName, userPrompt, systemInstruction, callback, hasFallenBack)
  hasFallenBack = hasFallenBack or false
  local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. modelName .. ":generateContent?key=" .. apiKey
  
  local payload = {
    contents = {
      {
        parts = {
          { text = userPrompt }
        }
      }
    }
  }

  if systemInstruction and systemInstruction ~= "" then
    payload.system_instruction = {
      parts = {
        { text = systemInstruction }
      }
    }
  end

  local headers = { ["Content-Type"] = "application/json" }
  
  Http.post(url, cjson.encode(payload), headers, function(status, data)
    if status == 200 and data then
      local ok, decoded = pcall(cjson.decode, data)
      if ok and decoded and decoded.candidates and decoded.candidates[1] 
         and decoded.candidates[1].content 
         and decoded.candidates[1].content.parts 
         and decoded.candidates[1].content.parts[1] then
        local text = decoded.candidates[1].content.parts[1].text
        callback(text)
      else
        Toast.makeText(service, "AI Response Parsing Error", Toast.LENGTH_SHORT).show()
        callback(nil)
      end
    elseif status == 429 and not hasFallenBack then
      local fallbackModel = "gemini-2.0-flash"
      if modelName == "gemini-2.0-flash" then
        fallbackModel = "gemini-1.5-flash"
      end
      Toast.makeText(service, "Model busy (429), trying backup model...", Toast.LENGTH_SHORT).show()
      Handler(Looper.getMainLooper()).postDelayed(Runnable{
        run = function()
          callGeminiAPI(apiKey, fallbackModel, userPrompt, systemInstruction, callback, true)
        end
      }, 1000)
    else
      local errorMsg = "AI Error (" .. tostring(status) .. "). Using raw text."
      if status == 429 then
        errorMsg = "AI Limit Reached (429). Using raw text."
      elseif status == 400 then
        errorMsg = "Error 400: Bad Request or Invalid Model parameters."
      elseif status == 403 then
        errorMsg = "Error 403: Permission Denied / Invalid Key."
      elseif data and data:find("API_KEY_INVALID", 1, true) then
        errorMsg = "Error: Your Gemini API Key is Invalid!"
      elseif data and data:find("404", 1, true) then
        errorMsg = "Error: Model name not found or unsupported."
      elseif status == -1 or status == 0 or not data or data == "" then
        errorMsg = "No internet connection. Check your internet connection."
      end
      Toast.makeText(service, errorMsg, Toast.LENGTH_LONG).show()
      speakDelayed(errorMsg)
      callback(nil)
    end
  end)
end

local function processWithAI(spokenText, langCode, transTarget, callback)
  local apiKey = getGeminiApiKey()
  if not apiKey or apiKey == "" then
    Toast.makeText(service, "Please enter Gemini API Key in Settings first!", Toast.LENGTH_SHORT).show()
    speakDelayed("Please enter Gemini API Key in Settings first!")
    callback(nil)
    return
  end

  local modelName = getSelectedModel()
  
  local isArabic = (langCode == "ar-SA" or transTarget == "Arabic")
  local emojiLevel = getEmojiLevel()
  local currentStyle = getWritingStyle()
  local emojiInstruction = ""
  
  if currentStyle == "Coding Mode" then
    emojiInstruction = "CRITICAL CODING MODE RULE: Strictly DO NOT insert, retain, or output any emojis, stickers, icons, or symbols under any circumstances. Zero emojis are permitted in Coding Mode regardless of any global emoji settings."
  elseif isArabic then
    emojiInstruction = "CRITICAL ARABIC RULE: Strictly DO NOT insert, retain, or output any emojis, stickers, icons, or symbols under any circumstances. Output clean text only."
  elseif emojiLevel == "Off" then
    emojiInstruction = "Strictly DO NOT insert any emojis or stickers."
  elseif emojiLevel == "Low" then
    emojiInstruction = "CRITICAL: Insert very few, minimal, and normal emojis sparingly throughout the text contextually."
  elseif emojiLevel == "Medium" then
    emojiInstruction = "CRITICAL: Carefully analyze the depth and emotions of the text and naturally insert moderate, balanced, and relevant emojis throughout the sentences contextually."
  elseif emojiLevel == "High" then
    emojiInstruction = "CRITICAL: Insert a high frequency of abundant, highly expressive, and multiple emojis and stickers throughout the text corresponding closely to the context and emotions."
  else
    emojiInstruction = "Strictly DO NOT insert any emojis or stickers."
  end

  local transInstruction = (transTarget and transTarget ~= "") and ("Translate the text entirely to " .. transTarget .. ".") or "Process the text in its input language."
  
  local styleInstruction = ""
  if currentStyle == "Story Writer" then
    styleInstruction = "MANDATORY: Write in a storytelling/narrative style. Expand the concepts into beautifully detailed, descriptive, and engaging paragraphs. Avoid short or brief summaries; make it immersive like a story book."
  elseif currentStyle == "Short Message" then
    styleInstruction = "MANDATORY: Keep the response short, extremely concise, direct, and to-the-point, suitable for quick SMS or instant messaging. Remove any fluff."
  elseif currentStyle == "Poetic" then
    styleInstruction = "MANDATORY: Enhance the vocabulary to make it artistic, deeply expressive, poetic, and highly literary, using beautiful phrasing while keeping the core meaning intact."
  elseif currentStyle == "Professional" then
    styleInstruction = "MANDATORY: Convert the tone into a formal, highly professional, polite, and corporate style, perfect for official emails and formal communication."
  elseif currentStyle == "Coding Mode" then
    styleInstruction = "MANDATORY CODING PROMPT OPTIMIZER MODE (ACCORDION/CODING MODE): The user is a blind developer who relies entirely on screen readers and voice-to-text workflows, providing a rough, broken, or Urdu/Roman Urdu instruction or idea for a coding task. Act as an expert AI prompt engineer and convert the user's input into a clear, professional, highly structured, detailed, and context-aware English prompt optimized for AI coding assistants. Explicitly incorporate the user's personal context and accessibility requirements (blind developer relying on screen readers and voice-to-text workflows) into the prompt instructions where relevant. ABSOLUTE STRICT RULE: Output ONLY the raw optimized English prompt text directly. Do NOT include any introductory phrases, labels, headings, greetings, conversational filler, or intro text like 'Here is the optimized prompt'."
  elseif currentStyle == "Custom Prompt" then
    local customP = getCustomPrompt()
    if customP and customP ~= "" then
      styleInstruction = "MANDATORY CUSTOM INSTRUCTION: Strictly process and format the input text following this custom user requirement: " .. customP
    else
      styleInstruction = "MANDATORY: Keep it in a standard, natural, conversational, and casual day-to-day chat format."
    end
  else
    styleInstruction = "MANDATORY: Keep it in a standard, natural, conversational, and casual day-to-day chat format."
  end
  
  local systemPrompt = [[You are an absolute text-processing tool and typing engine for an input dictation app.

ABSOLUTE TOP-PRIORITY RULE (TEXT DICTATION ENGINE):
1. You are NOT a chatbot. You MUST NOT chat, answer questions, or reply to statements or greetings.
2. ABSOLUTE GREETING OVERRIDE: If the input text contains "السلام علیکم" or any greeting, you MUST retain "السلام علیکم" verbatim in the output. STRICTLY DO NOT convert "السلام علیکم" to "وعلیکم السلام" under any circumstances. Never output "وعلیکم السلام" when the user said "السلام علیکم".
3. Transcribe and format ONLY what the user dictated, fixing only grammar, flow, and formatting, without altering the core intended phrase or exchanging it for a response.

UNIVERSAL RULES FOR ALL MODES:
1. CRITICAL: Perfect grammar, flawless sentence structure, and correct spelling are absolutely mandatory for every single response.
2. Fix all punctuation, flow, and spacing issues seamlessly.
3. IMPORTANT: Automatically detect and intelligently handle mixed languages, conversational slang, or Roman scripts (like Roman Urdu/Hindi/Punjabi), and seamlessly convert or refine them into their appropriate formal or natural script context.
4. IMPORTANT LANGUAGE RULES:
   - When writing in Urdu, strictly follow Urdu grammatical rules, punctuation (using Urdu full stop '۔'), and sentence structure.
   - When writing in Hindi, strictly follow Hindi grammatical rules, punctuation (using Hindi full stop '|'), and sentence structure.
   - When writing in Punjabi, MANDATORY: Use the Shahmukhi script (Urdu-based script used in Pakistan). Strictly follow the grammar, punctuation, and orthography of Pakistani Punjabi (Shahmukhi). Do not use Gurmukhi script.
   - When writing or translating into Arabic, strictly follow classical and formal Arabic grammatical rules, flawless syntax, proper diacritical marks/tashkeel (zabar, zer, pesh, jazm, tanween) where required, and accurate Quranic orthography whenever Quranic verses, Islamic phrases, or Arabic translations are requested.
5. STRICT ENGLISH PRESERVATION RULE (NO URDU TRANSLITERATION): When writing in Urdu or any native script, EVERY English word, loanword, technical term, app name, brand name, software name, or English vocabulary item (such as "public", "community", "Advance Typer", "import", "software", etc.) MUST BE WRITTEN STRICTLY IN ENGLISH/LATIN SCRIPT. Never convert, translate, or transliterate English words into Urdu alphabet/script (e.g., always write "public" and "community", never "پبلک" or "کمیونٹی"). Ensure a natural, mixed-language digital communication flow.
6. SPECIAL OVERRIDE RULE FOR NAMES AND CONTACT FIELDS: Automatically detect if the input text is a person's name, a contact name, an email address, or a short identifier (like "Muddassir", "Muhammad", etc.). If it is a name or contact field, you must output ONLY the clean, correctly spelled name/identifier in proper capitalization. Strictly DO NOT add any emojis, stickers, unnecessary punctuation, or extra conversational filler words to it.
7. ]] .. emojiInstruction .. [[
8. ]] .. transInstruction .. [[

SPECIFIC STYLE INSTRUCTION (YOU MUST FOLLOW THIS OVERRIDE):
]] .. styleInstruction .. [[

9. Return ONLY the final polished text. Do NOT include any explanations, greetings, introduction, or notes.]]

  callGeminiAPI(apiKey, modelName, spokenText, systemPrompt, function(result)
    if not result then
      callback(nil)
      return
    end
    local finalResult = result
    saveAIText(finalResult)
    callback(finalResult)
  end)
end

local showSettingsDialog
local showMyDialog
local showDictionarySettings

local function showEmojiSettingsDialog()
  local dlg = LuaDialog()
  registerDialog(dlg)
  local layout = LinearLayout(service)
  layout.setOrientation(1)
  layout.setPadding(30, 20, 30, 20)
  
  local heading = TextView(service)
  heading.setText("Emoji Settings")
  heading.setTextSize(20)
  heading.setPadding(0, 0, 0, 15)
  layout.addView(heading)
  
  local currentLevel = getEmojiLevel()
  
  local offBtn = Button(service)
  offBtn.setText("OFF" .. (currentLevel == "Off" and " (Selected)" or ""))
  offBtn.setOnClickListener(function()
    setEmojiLevel("Off")
    Toast.makeText(service, "Emoji set to OFF", Toast.LENGTH_SHORT).show()
    speakDelayed("Emoji OFF")
    unregisterDialog(dlg)
    dlg.dismiss()
    showSettingsDialog()
  end)
  layout.addView(offBtn)
  
  local lowBtn = Button(service)
  lowBtn.setText("LOW" .. (currentLevel == "Low" and " (Selected)" or ""))
  lowBtn.setOnClickListener(function()
    setEmojiLevel("Low")
    Toast.makeText(service, "Emoji set to LOW", Toast.LENGTH_SHORT).show()
    speakDelayed("Emoji LOW")
    unregisterDialog(dlg)
    dlg.dismiss()
    showSettingsDialog()
  end)
  layout.addView(lowBtn)
  
  local medBtn = Button(service)
  medBtn.setText("MEDIUM" .. (currentLevel == "Medium" and " (Selected)" or ""))
  medBtn.setOnClickListener(function()
    setEmojiLevel("Medium")
    Toast.makeText(service, "Emoji set to MEDIUM", Toast.LENGTH_SHORT).show()
    speakDelayed("Emoji MEDIUM")
    unregisterDialog(dlg)
    dlg.dismiss()
    showSettingsDialog()
  end)
  layout.addView(medBtn)
  
  local highBtn = Button(service)
  highBtn.setText("HIGH" .. (currentLevel == "High" and " (Selected)" or ""))
  highBtn.setOnClickListener(function()
    setEmojiLevel("High")
    Toast.makeText(service, "Emoji set to HIGH", Toast.LENGTH_SHORT).show()
    speakDelayed("Emoji HIGH")
    unregisterDialog(dlg)
    dlg.dismiss()
    showSettingsDialog()
  end)
  layout.addView(highBtn)
  
  dlg.setView(layout)
  dlg.show()
end

showSettingsDialog = function()
  local dlg = LuaDialog()
  registerDialog(dlg)
  local mainLayout = LinearLayout(service)
  mainLayout.setOrientation(1)
  mainLayout.setPadding(30, 20, 30, 20)
  
  local title = TextView(service)
  title.setText("Settings")
  title.setTextSize(20)
  mainLayout.addView(title)
  
  local keyLabel = TextView(service)
  keyLabel.setText("Enter Gemini API Key")
  keyLabel.setTextSize(16)
  keyLabel.setPadding(0, 10, 0, 5)
  mainLayout.addView(keyLabel)
  
  local keyInput = EditText(service)
  keyInput.setHint("Enter Gemini API Key")
  keyInput.setText(getGeminiApiKey())
  mainLayout.addView(keyInput)
  
  local testApiBtn = Button(service)
  testApiBtn.setText("TEST API KEY")
  testApiBtn.setOnClickListener(function()
    local apiKey = keyInput.getText().toString()
    if not apiKey or apiKey == "" then
      Toast.makeText(service, "Please enter API Key first!", Toast.LENGTH_SHORT).show()
      speakDelayed("Please enter API Key first!")
      return
    end

    local url = "https://generativelanguage.googleapis.com/v1beta/models?key=" .. apiKey
    Toast.makeText(service, "Testing API Key...", Toast.LENGTH_SHORT).show()

    Http.get(url, function(status, data)
      if status == 200 and data then
        local ok, decoded = pcall(cjson.decode, data)
        if ok and decoded and decoded.models then
          Toast.makeText(service, "Google Gemini API Key is Valid", Toast.LENGTH_SHORT).show()
          speakDelayed("Google Gemini API Key is Valid")
        else
          Toast.makeText(service, "Google Gemini API Key is Valid", Toast.LENGTH_SHORT).show()
          speakDelayed("Google Gemini API Key is Valid")
        end
      else
        if data and data:find("API_KEY_INVALID", 1, true) then
          Toast.makeText(service, "Google Gemini API Key is Invalid", Toast.LENGTH_SHORT).show()
          speakDelayed("Google Gemini API Key is Invalid")
        elseif status == -1 or status == 0 or not data or data == "" then
          Toast.makeText(service, "Check your internet connection", Toast.LENGTH_SHORT).show()
          speakDelayed("Check your internet connection")
        else
          Toast.makeText(service, "Google Gemini API Key is Invalid", Toast.LENGTH_SHORT).show()
          speakDelayed("Google Gemini API Key is Invalid")
        end
      end
    end)
  end)
  mainLayout.addView(testApiBtn)

  local saveBtn = Button(service)
  saveBtn.setText("SAVE")
  saveBtn.setOnClickListener(function()
    saveGeminiApiKey(keyInput.getText().toString())
    speakDelayed("API Key Saved Successfully")
    Toast.makeText(service, "API Key Saved Successfully", Toast.LENGTH_SHORT).show()
  end)
  mainLayout.addView(saveBtn)
  
  local getApiBtn = Button(service)
  getApiBtn.setText("GET API KEY")
  getApiBtn.setOnClickListener(function()
    local intent = Intent(Intent.ACTION_VIEW)
    intent.setData(Uri.parse("https://console.cloud.google.com/apis/credentials/key"))
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    service.getApplicationContext().startActivity(intent)
    dismissAllDialogs()
  end)
  mainLayout.addView(getApiBtn)
  
  local updateModelsBtn = Button(service)
  updateModelsBtn.setText("UPDATE MODEL")
  mainLayout.addView(updateModelsBtn)

  local checkUpdatesSettingsBtn = Button(service)
  checkUpdatesSettingsBtn.setText("Check for Updates")
  mainLayout.addView(checkUpdatesSettingsBtn)
  checkUpdatesSettingsBtn.setOnClickListener(function()
    checkUpdate(true)
  end)

  local modelSpinner = Spinner(service)
  local savedModelsStr = aiPrefs.getString("saved_models_list", "")
  local availableModels = {}
  if savedModelsStr and savedModelsStr ~= "" then
    for m in savedModelsStr:gmatch("[^,]+") do
      table.insert(availableModels, m)
    end
  end
  if #availableModels == 0 then
    availableModels = {"gemini-1.5-flash", "gemini-1.5-pro", "gemini-2.0-flash"}
  end

  local displayModels = {}
  for _, m in ipairs(availableModels) do
    table.insert(displayModels, getModelDisplayName(m))
  end

  local adapterM = ArrayAdapter(service, android.R.layout.simple_spinner_item, displayModels)
  modelSpinner.setAdapter(adapterM)
  
  local currentModel = getSelectedModel()
  for idx, m in ipairs(availableModels) do
    if m == currentModel then
      modelSpinner.setSelection(idx - 1)
      break
    end
  end
  mainLayout.addView(modelSpinner)

  modelSpinner.setOnItemSelectedListener(AdapterView.OnItemSelectedListener{
    onItemSelected = function(parent, view, position, id)
      local chosenModel = tostring(modelSpinner.getSelectedItem())
      if chosenModel and chosenModel ~= "" then
        local rawModel = chosenModel:match("^([^%s]+)")
        if rawModel and rawModel ~= "" then
          setSelectedModel(rawModel)
        end
      end
    end,
    onNothingSelected = function() end
  })

  local styleLabel = TextView(service)
  styleLabel.setText("Typing Mode (ٹائپنگ موڈ)")
  styleLabel.setTextSize(16)
  styleLabel.setPadding(0, 10, 0, 5)
  mainLayout.addView(styleLabel)

  local styleSpinner = Spinner(service)
  local rawStyles = {"Casual", "Professional", "Story Writer", "Poetic", "Short Message", "Coding Mode", "Custom Prompt"}
  local displayStyles = {
    "Casual (روزمرہ اور عام گفتگو کے لیے آسان اور فطری انداز)",
    "Professional (آفیشل ای میلز اور کاروباری گفتگو کے لیے رسمی انداز)",
    "Story Writer (تفصیلی اور خوبصورت کہانی، مضامین یا تفصیلی پیراگراف لکھنے کے لیے)",
    "Poetic (ادبی، شاعری اور گہرے جذبات والے الفاظ کے لیے)",
    "Short Message (شارٹ میسجز، ایس ایم ایس اور انتہائی مختصر اور ٹو دی پوائنٹ بات کے لیے)",
    "Coding Mode (اردو یا عام زبان کے کوڈنگ آئیڈیاز کو ایک بہترین اور پروفیشنل انگلش پرامپٹ میں تبدیل کرنے کے لیے)",
    "Custom Prompt (اپنی مرضی کی کسٹم انسٹرکشن کے مطابق لکھائی کے لیے)"
  }

  local adapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, displayStyles)
  styleSpinner.setAdapter(adapter)
  
  local currentStyle = getWritingStyle()
  for idx, s in ipairs(rawStyles) do
    if s == currentStyle then
      styleSpinner.setSelection(idx - 1)
      break
    end
  end
  mainLayout.addView(styleSpinner)

  local customPromptInput = EditText(service)
  customPromptInput.setHint("Enter Custom Prompt Here...")
  customPromptInput.setText(getCustomPrompt())
  
  if currentStyle == "Custom Prompt" then
    customPromptInput.setVisibility(View.VISIBLE)
  else
    customPromptInput.setVisibility(View.GONE)
  end
  mainLayout.addView(customPromptInput)

  customPromptInput.addTextChangedListener(TextWatcher{
    onTextChanged = function(s, start, before, count)
      setCustomPrompt(tostring(s))
    end
  })

  styleSpinner.setOnItemSelectedListener(AdapterView.OnItemSelectedListener{
    onItemSelected = function(parent, view, position, id)
      local selectedPos = position + 1
      local styleStr = rawStyles[selectedPos]
      if styleStr then
        setWritingStyle(styleStr)
        if styleStr == "Custom Prompt" then
          customPromptInput.setVisibility(View.VISIBLE)
        else
          customPromptInput.setVisibility(View.GONE)
        end
      end
    end,
    onNothingSelected = function() end
  })

  local langSpinner = Spinner(service)
  local langAdapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, {"Manual Select", "Urdu (Pakistan)", "English (US)", "Hindi (India)", "Punjabi (Pakistan)", "Arabic"})
  langSpinner.setAdapter(langAdapter)
  local langCodes = {"Manual Select", "ur-PK", "en-US", "hi-IN", "pa-PK", "ar-SA"}
  local currentLangCode = getDefaultLanguage()
  local currentLangIndex = 0
  for i, code in ipairs(langCodes) do
    if code == currentLangCode or (code == "Manual Select" and currentLangCode == "Auto") then
      currentLangIndex = i - 1
      break
    end
  end
  langSpinner.setSelection(currentLangIndex)
  mainLayout.addView(langSpinner)

  langSpinner.setOnItemSelectedListener(AdapterView.OnItemSelectedListener{
    onItemSelected = function(parent, view, position, id)
      local selectedLangPos = position + 1
      setDefaultLanguage(langCodes[selectedLangPos])
    end,
    onNothingSelected = function() end
  })

  local emojiSettingsBtn = Button(service)
  emojiSettingsBtn.setText("Emoji Settings")
  mainLayout.addView(emojiSettingsBtn)
  emojiSettingsBtn.setOnClickListener(function()
    unregisterDialog(dlg)
    dlg.dismiss()
    showEmojiSettingsDialog()
  end)
  
  local currentTransState = isTranslationEnabled()
  local transToggle = Button(service)
  transToggle.setText(currentTransState and "TRANSLATION: ON" or "TRANSLATION: OFF")
  mainLayout.addView(transToggle)
  transToggle.setOnClickListener(function(v)
    local apiKey = getGeminiApiKey()
    if not apiKey or apiKey == "" then
      Toast.makeText(service, "Please enter Gemini API Key in Settings first!", Toast.LENGTH_SHORT).show()
      speakDelayed("Please enter Gemini API Key in Settings first!")
      return
    end
    currentTransState = not currentTransState
    setTranslationEnabled(currentTransState)
    v.setText(currentTransState and "TRANSLATION: ON" or "TRANSLATION: OFF")
  end)

  local currentAutoStartState = aiPrefs.getBoolean("auto_start_enabled", true)
  local autoStartToggle = Button(service)
  autoStartToggle.setText(currentAutoStartState and "Automatically start voice typing if text box is detected: ON" or "Automatically start voice typing if text box is detected: OFF")
  mainLayout.addView(autoStartToggle)
  autoStartToggle.setOnClickListener(function(v)
    currentAutoStartState = not currentAutoStartState
    aiEditor.putBoolean("auto_start_enabled", currentAutoStartState)
    aiEditor.apply()
    v.setText(currentAutoStartState and "Automatically start voice typing if text box is detected: ON" or "Automatically start voice typing if text box is detected: OFF")
    Toast.makeText(service, currentAutoStartState and "Auto-start enabled" or "Auto-start disabled", Toast.LENGTH_SHORT).show()
  end)

  local backBtn = Button(service)
  backBtn.setText("GO BACK")
  mainLayout.addView(backBtn)

  updateModelsBtn.setOnClickListener(function()
    local apiKey = keyInput.getText().toString()
    if not apiKey or apiKey == "" then
      Toast.makeText(service, "Please enter Gemini API Key in Settings first!", Toast.LENGTH_SHORT).show()
      speakDelayed("Please enter Gemini API Key in Settings first!")
      return
    end

    local url = "https://generativelanguage.googleapis.com/v1beta/models?key=" .. apiKey
    Toast.makeText(service, "Checking for updates...", Toast.LENGTH_SHORT).show()

    Http.get(url, function(status, data)
      if status == 200 and data then
        local ok, decoded = pcall(cjson.decode, data)
        if ok and decoded and decoded.models then
          local modelNames = {}
          local modelDetailsList = {}
          local seenModels = {}

          for _, model in ipairs(decoded.models) do
            if model.name then
              local cleanName = model.name:gsub("models/", "")
              local supportsGenerate = false
              if model.supportedGenerationMethods then
                for _, method in ipairs(model.supportedGenerationMethods) do
                  if method == "generateContent" then
                    supportsGenerate = true
                    break
                  end
                end
              else
                supportsGenerate = true
              end

              local isGemini = (cleanName:find("gemini", 1, true) ~= nil)
              local isExcluded = (cleanName:find("embedding", 1, true) ~= nil) or
                                 (cleanName:find("imagen", 1, true) ~= nil) or
                                 (cleanName:find("image", 1, true) ~= nil) or
                                 (cleanName:find("audio", 1, true) ~= nil) or
                                 (cleanName:find("tts", 1, true) ~= nil) or
                                 (cleanName:find("bison", 1, true) ~= nil) or
                                 (cleanName:find("vision", 1, true) ~= nil) or
                                 (cleanName:find("robotics", 1, true) ~= nil) or
                                 (cleanName:find("computer", 1, true) ~= nil) or
                                 (cleanName:find("customtools", 1, true) ~= nil) or
                                 (cleanName:find("tunedModels", 1, true) ~= nil)

              local isFlashOrPro = (cleanName:find("flash", 1, true) ~= nil) or (cleanName:find("pro", 1, true) ~= nil)
              local isExperimental = (cleanName:find("exp", 1, true) ~= nil) or (cleanName:find("preview", 1, true) ~= nil)

              if isGemini and supportsGenerate and not isExcluded and isFlashOrPro and not isExperimental and not seenModels[cleanName] then
                seenModels[cleanName] = true
                table.insert(modelNames, cleanName)

                local desc = "ٹیکسٹ اور وائس ٹائپنگ کے لیے موزوں ماڈل"
                if cleanName:find("flash%-lite") then
                  desc = "کوئیک میسجز کے لیے انتہائی ہلکا اور فاسٹ ماڈل"
                elseif cleanName:find("flash") then
                  desc = "روزمرہ کی فاسٹ وائس ٹائپنگ کے لیے تیز ترین ماڈل"
                elseif cleanName:find("pro") then
                  desc = "زیادہ ذہین، گرامر اور بہترین ٹیکسٹ ایڈیٹنگ ماڈل"
                end
                table.insert(modelDetailsList, "• " .. cleanName .. "\n  (" .. desc .. ")")
              end
            end
          end

          if #modelNames > 0 then
            local newModelsStr = table.concat(modelNames, ",")
            local currentSavedModelsStr = aiPrefs.getString("saved_models_list", "")

            if newModelsStr == currentSavedModelsStr and currentSavedModelsStr ~= "" then
              Toast.makeText(service, "Update Not Found", Toast.LENGTH_SHORT).show()
              speakDelayed("Update Not Found")
            else
              aiEditor.putString("saved_models_list", newModelsStr)
              aiEditor.apply()

              local displayModelNames = {}
              for _, m in ipairs(modelNames) do
                table.insert(displayModelNames, getModelDisplayName(m))
              end

              local newAdapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, displayModelNames)
              modelSpinner.setAdapter(newAdapter)
              
              local successDlg = LuaDialog()
              registerDialog(successDlg)
              successDlg.setTitle("Update Status")
              
              local successLayout = LinearLayout(service)
              successLayout.setOrientation(1)
              successLayout.setPadding(30, 20, 30, 20)
              
              local headTv = TextView(service)
              headTv.setText("Update Successfully!\n\nآپ کے ماڈلز کی تفصیل ذیل میں درج ہے:")
              headTv.setTextSize(16)
              headTv.setPadding(0, 0, 0, 15)
              successLayout.addView(headTv)
              
              local scrollView = ScrollView(service)
              local scrollContainer = LinearLayout(service)
              scrollContainer.setOrientation(1)
              
              for _, infoText in ipairs(modelDetailsList) do
                local itemTv = TextView(service)
                itemTv.setText(infoText)
                itemTv.setTextSize(15)
                itemTv.setPadding(0, 10, 0, 10)
                scrollContainer.addView(itemTv)
              end
              
              scrollView.addView(scrollContainer)
              successLayout.addView(scrollView, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1.0))
              
              local closeDlgBtn = Button(service)
              closeDlgBtn.setText("CLOSE")
              closeDlgBtn.setOnClickListener(function()
                unregisterDialog(successDlg)
                successDlg.dismiss()
              end)
              successLayout.addView(closeDlgBtn)
              
              successDlg.setView(successLayout)
              successDlg.show()
              speakDelayed("Update Successfully")
            end
          else
            Toast.makeText(service, "Update Not Found", Toast.LENGTH_SHORT).show()
            speakDelayed("Update Not Found")
          end
        else
          Toast.makeText(service, "Update Not Found", Toast.LENGTH_SHORT).show()
          speakDelayed("Update Not Found")
        end
      else
        if data and data:find("API_KEY_INVALID", 1, true) then
          Toast.makeText(service, "Error: Your Gemini API Key is Invalid!", Toast.LENGTH_SHORT).show()
          speakDelayed("Your Gemini API Key is Invalid")
        elseif status == -1 or status == 0 or not data or data == "" then
          Toast.makeText(service, "Check your internet connection", Toast.LENGTH_SHORT).show()
          speakDelayed("Check your internet connection")
        else
          Toast.makeText(service, "Update Not Found", Toast.LENGTH_SHORT).show()
          speakDelayed("Update Not Found")
        end
      end
    end)
  end)

  backBtn.setOnClickListener(function() unregisterDialog(dlg); dlg.dismiss() end)
  dlg.setView(mainLayout)
  dlg.show()
end

local function showAITextsDialog()
  local textsList = getAITextsList()
  if #textsList == 0 then
    Toast.makeText(service, "No history available yet", Toast.LENGTH_SHORT).show()
    service.speak("No history available yet")
    return
  end
  
  local dlg = LuaDialog()
  registerDialog(dlg)
  dlg.setTitle("AI Texts & Code History")
  
  local container = LinearLayout(service)
  container.setOrientation(1)
  container.setPadding(30, 20, 30, 20)
  
  local infoTv = TextView(service)
  infoTv.setText("Tap or long press any item to copy generated text / code block:")
  infoTv.setTextSize(14)
  infoTv.setPadding(0, 0, 0, 10)
  container.addView(infoTv)
  
  local displayTexts = {}
  for i, t in ipairs(textsList) do
    table.insert(displayTexts, t)
  end
  
  local list = ListView(service)
  local adapter = ArrayAdapter(service, android.R.layout.simple_list_item_1, displayTexts)
  list.setAdapter(adapter)
  
  local function copyTextToClipboard(selectedText)
    local clipboard = service.getSystemService(Context.CLIPBOARD_SERVICE)
    local clip = ClipData.newPlainText("AI Output", selectedText)
    clipboard.setPrimaryClip(clip)
    Toast.makeText(service, "Copied to clipboard successfully", Toast.LENGTH_SHORT).show()
    service.speak("Copied to clipboard successfully")
  end
  
  list.setOnItemClickListener(function(parent, v, pos, id)
    local selectedText = textsList[pos+1]
    if selectedText then
      copyTextToClipboard(selectedText)
      unregisterDialog(dlg)
      dlg.dismiss()
    end
  end)
  
  list.setOnItemLongClickListener(function(parent, v, pos, id)
    local selectedText = textsList[pos+1]
    if selectedText then
      copyTextToClipboard(selectedText)
      unregisterDialog(dlg)
      dlg.dismiss()
    end
    return true
  end)
  
  container.addView(list, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1.0))
  
  local copyLatestBtn = Button(service)
  copyLatestBtn.setText("Copy Latest Text / Code")
  copyLatestBtn.setOnClickListener(function()
    if #textsList > 0 then
      copyTextToClipboard(textsList[1])
      unregisterDialog(dlg)
      dlg.dismiss()
    end
  end)
  container.addView(copyLatestBtn)
  
  local backBtn = Button(service)
  backBtn.setText("GO BACK")
  backBtn.setOnClickListener(function() unregisterDialog(dlg); dlg.dismiss() end)
  container.addView(backBtn)
  
  dlg.setView(container)
  dlg.show()
end

showDictionarySettings = function()
  local dlg = LuaDialog()
  registerDialog(dlg)
  local layout = LinearLayout(service)
  layout.setOrientation(1)
  layout.setPadding(30, 20, 30, 20)
  
  local wrongInput = EditText(service)
  wrongInput.setHint("Wrong Word")
  layout.addView(wrongInput)
  
  local correctInput = EditText(service)
  correctInput.setHint("Correct Word")
  layout.addView(correctInput)
  
  local addBtn = Button(service)
  addBtn.setText("Add to Dictionary")
  layout.addView(addBtn)
  
  local listLabel = TextView(service)
  listLabel.setText("Saved Dictionary Items:")
  listLabel.setTextSize(16)
  listLabel.setPadding(0, 15, 0, 5)
  layout.addView(listLabel)
  
  local listView = ListView(service)
  
  local function refreshDictionaryList()
    local dict = getDictionary()
    local entries = {}
    local displayItems = {}
    for wrong, correct in pairs(dict) do
      if correct and correct ~= "" then
        table.insert(entries, { wrong = wrong, correct = correct })
        table.insert(displayItems, wrong .. " -> " .. correct)
      end
    end
    local adapter = ArrayAdapter(service, android.R.layout.simple_list_item_1, displayItems)
    listView.setAdapter(adapter)
    return entries
  end
  
  local entries = refreshDictionaryList()
  
  listView.setOnItemLongClickListener(function(parent, v, pos, id)
    local targetEntry = entries[pos+1]
    if targetEntry then
      local dDlg = LuaDialog()
      registerDialog(dDlg)
      dDlg.setTitle("Delete Word?")
      dDlg.setMessage("Are you sure you want to delete '" .. targetEntry.correct .. "'?")
      dDlg.setPositiveButton("Yes", function()
        local dict = getDictionary()
        dict[targetEntry.wrong] = nil
        saveDictionary(dict)
        unregisterDialog(dDlg)
        dDlg.dismiss()
        Toast.makeText(service, "Deleted successfully", Toast.LENGTH_SHORT).show()
        speakDelayed("Deleted successfully")
        entries = refreshDictionaryList()
      end)
      dDlg.setNegativeButton("No", function()
        unregisterDialog(dDlg)
        dDlg.dismiss()
      end)
      dDlg.show()
    end
    return true
  end)
  
  layout.addView(listView, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1.0))
  
  local closeBtn = Button(service)
  closeBtn.setText("CLOSE")
  closeBtn.setOnClickListener(function() unregisterDialog(dlg); dlg.dismiss() end)
  layout.addView(closeBtn)
  
  addBtn.setOnClickListener(function()
    local w = wrongInput.getText().toString()
    local c = correctInput.getText().toString()
    if w ~= "" and c ~= "" then
      local dict = getDictionary()
      dict[w] = c
      saveDictionary(dict)
      
      wrongInput.setText("")
      correctInput.setText("")
      
      pcall(function()
        local imm = service.getSystemService(Context.INPUT_METHOD_SERVICE)
        if imm then
          imm.hideSoftInputFromWindow(wrongInput.getWindowToken(), 0)
          imm.hideSoftInputFromWindow(correctInput.getWindowToken(), 0)
        end
      end)
      
      Toast.makeText(service, "Added Successfully", Toast.LENGTH_SHORT).show()
      speakDelayed("Added Successfully")
      
      entries = refreshDictionaryList()
    else
      Toast.makeText(service, "Please fill both fields", Toast.LENGTH_SHORT).show()
    end
  end)
  
  dlg.setView(layout)
  dlg.show()
end

showMyDialog = function()
  local dlg = LuaDialog()
  registerDialog(dlg)
  dlg.setTitle("Advance Typer v" .. CURRENT_VERSION)
  local layout = { LinearLayout; orientation = "vertical"; padding = "30dp";
    { TextView; text = "Developer: Hafiz Muddassir Safi"; textSize = "16sp"; layout_marginBottom="10dp"; gravity = "center"; };
    { Button; text = "AI Texts"; textSize = "16sp"; onClick = function() showAITextsDialog() end; };
    { Button; text = "Dictionary"; textSize = "16sp"; layout_marginTop="10dp"; onClick = function() showDictionarySettings() end; };
    { Button; text = "Settings"; textSize = "16sp"; layout_marginTop="10dp"; onClick = function() showSettingsDialog() end; };
    { Button; text = "Send Feedback to Developer"; textSize = "16sp"; layout_marginTop="10dp"; onClick = function()
        local intent = Intent(Intent.ACTION_VIEW)
        intent.setData(Uri.parse("https://wa.me/923044552704"))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        service.getApplicationContext().startActivity(intent)
        dismissAllDialogs()
      end; };
    { Button; text = "Exit"; textSize = "16sp"; layout_marginTop="10dp"; onClick = function() unregisterDialog(dlg); dlg.dismiss() end; };
  }
  dlg.setView(loadlayout(layout))
  dlg.show()
end

local editText = service.getEditText()
local global_node = node

local function startVoiceTyping(langCode, transTarget)
  local context = service.getApplicationContext()
  local speechRec = SpeechRecognizer.createSpeechRecognizer(context)
  
  local listener = RecognitionListener {
    onResults = function(results)
      local resultsArray = results.getParcelableArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
      if resultsArray and resultsArray.size() > 0 then
        local rawSpokenText = resultsArray.get(0)
        
        local trimmedText = rawSpokenText:match("^%s*(.-)%s*$") or rawSpokenText
        local lowerText = trimmedText:lower()
        
        if lowerText == "emoji on" or lowerText == "ایموجی آن" then
          setEmojiLevel("Medium")
          Toast.makeText(service, "Emoji Enabled via Voice (Medium)", Toast.LENGTH_SHORT).show()
          service.speak("Emoji Enabled")
          speechRec.destroy()
          return
        elseif lowerText == "emoji off" or lowerText == "ایموجی آف" then
          setEmojiLevel("Off")
          Toast.makeText(service, "Emoji Disabled via Voice", Toast.LENGTH_SHORT).show()
          service.speak("Emoji Disabled")
          speechRec.destroy()
          return
        elseif lowerText == "translation on" or lowerText == "ٹرانسلیشن آن" then
          setTranslationEnabled(true)
          Toast.makeText(service, "Translation Enabled via Voice", Toast.LENGTH_SHORT).show()
          service.speak("Translation Enabled")
          speechRec.destroy()
          return
        elseif lowerText == "translation off" or lowerText == "ٹرانسلیشن آف" then
          setTranslationEnabled(false)
          Toast.makeText(service, "Translation Disabled via Voice", Toast.LENGTH_SHORT).show()
          service.speak("Translation Disabled")
          speechRec.destroy()
          return
        elseif lowerText == "casual mode" then
          setWritingStyle("Casual")
          Toast.makeText(service, "Style set to Casual", Toast.LENGTH_SHORT).show()
          service.speak("Casual Mode")
          speechRec.destroy()
          return
        elseif lowerText == "professional mode" then
          setWritingStyle("Professional")
          Toast.makeText(service, "Style set to Professional", Toast.LENGTH_SHORT).show()
          service.speak("Professional Mode")
          speechRec.destroy()
          return
        elseif lowerText == "coding mode" or lowerText == "کوڈنگ موڈ" then
          setWritingStyle("Coding Mode")
          Toast.makeText(service, "Style set to Coding Mode", Toast.LENGTH_SHORT).show()
          service.speak("Coding Mode")
          speechRec.destroy()
          return
        end
        
        local spokenText = applyDictionary(rawSpokenText)
        
        processWithAI(spokenText, langCode, transTarget, function(enhancedText)
          local finalOutput = enhancedText or spokenText
          local currentEdit = service.getEditText()
          if currentEdit then
            service.insertText(currentEdit, finalOutput)
          elseif global_node then
            service.insertText(global_node, finalOutput)
          end
          service.speak(finalOutput)
        end)
      end
      speechRec.destroy()
    end,
    onEndOfSpeech = function() speechRec.stopListening() end,
    onError = function(errorCode)
      speechRec.destroy()
      Toast.makeText(service, "Speech Recognition Error: " .. tostring(errorCode), Toast.LENGTH_SHORT).show()
    end,
  }
  
  local intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
  intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
  intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, langCode)
  intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, langCode)
  intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
  speechRec.setRecognitionListener(listener)
  speechRec.startListening(intent)
end

local function showQuickMenu()
  local dlg = LuaDialog()
  registerDialog(dlg)
  dlg.setTitle("Quick Option")
  
  local container = LinearLayout(service)
  container.setOrientation(1)
  
  local options = {
    "Translate Text",
    "Process Focused Text",
    "Summarize Text",
    "Poetry Writer",
    "Convert Roman Text",
    "Smart Data Extractor",
    "Go to Main Menu"
  }
  
  local list = ListView(service)
  local adapter = ArrayAdapter(service, android.R.layout.simple_list_item_1, options)
  list.setAdapter(adapter)
  
  list.setOnItemClickListener(function(parent, v, pos, id)
    if pos >= 0 and pos <= 5 then
      local apiKey = getGeminiApiKey()
      if not apiKey or apiKey == "" then
        Toast.makeText(service, "Please enter Gemini API Key in Settings first!", Toast.LENGTH_LONG).show()
        speakDelayed("Please enter Gemini API Key in Settings first!")
        return
      end
    end

    unregisterDialog(dlg)
    dlg.dismiss()
    
    local currentText = ""
    local currentEdit = service.getEditText()
    if currentEdit then
      pcall(function() currentText = currentEdit.getText().toString() end)
    end
    if (not currentText or currentText == "") and global_node then
      pcall(function()
        if global_node.getText() then
          currentText = tostring(global_node.getText())
        end
      end)
    end
    
    local function setTextBack(res)
      if not res then return end
      local success = false
      
      if global_node then
        pcall(function()
          local args = Bundle()
          args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, res)
          success = global_node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        end)
      end
      
      if not success then
        pcall(function()
          local ed = service.getEditText()
          if ed then
            ed.setText(res)
            success = true
          elseif global_node then
            service.insertText(global_node, res)
            success = true
          end
        end)
      end
      
      if not success then
        pcall(function()
          local clipboard = service.getSystemService(Context.CLIPBOARD_SERVICE)
          local clip = ClipData.newPlainText("AI Output", res)
          clipboard.setPrimaryClip(clip)
          if global_node then
            global_node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
          end
        end)
      end
    end
    
    if pos == 0 then
      local tDlg = LuaDialog()
      registerDialog(tDlg)
      tDlg.setTitle("Translate to?")
      local tList = ListView(service)
      local transLangs = {"Urdu", "English", "Hindi", "Punjabi", "Arabic"}
      tList.setAdapter(ArrayAdapter(service, android.R.layout.simple_list_item_1, transLangs))
      tList.setOnItemClickListener(function(p, v2, p2, i)
        unregisterDialog(tDlg)
        tDlg.dismiss()
        if currentText ~= "" then
          speakDelayed("Translating, please wait")
          Handler(Looper.getMainLooper()).postDelayed(Runnable{
            run = function()
              processWithAI(currentText, "en-US", transLangs[p2+1], function(res)
                if res then
                  setTextBack(res)
                  service.speak("Translated successfully")
                end
              end)
            end
          }, 1000)
        else
          Toast.makeText(service, "No text found in edit box!", Toast.LENGTH_SHORT).show()
        end
      end)
      tDlg.setView(tList)
      tDlg.show()
      
    elseif pos == 1 then
      if currentText ~= "" then
        speakDelayed("Processing text, please wait")
        
        Handler(Looper.getMainLooper()).postDelayed(Runnable{
          run = function()
            local apiKey = getGeminiApiKey()
            local modelName = getSelectedModel()
            local prompt = "Fix all grammar, spelling, punctuation, and flow of this text while keeping the exact meaning intact. Return ONLY the polished text: " .. currentText
            callGeminiAPI(apiKey, modelName, prompt, "You are a professional grammar and text editor.", function(res)
              if res then
                saveAIText(res)
                setTextBack(res)
                service.speak("Text processed successfully")
              end
            end)
          end
        }, 1000)
      else
        Toast.makeText(service, "No text found in edit box!", Toast.LENGTH_SHORT).show()
      end
      
    elseif pos == 2 then
      if currentText ~= "" then
        speakDelayed("Summarizing text, please wait")
        
        Handler(Looper.getMainLooper()).postDelayed(Runnable{
          run = function()
            local apiKey = getGeminiApiKey()
            local modelName = getSelectedModel()
            local prompt = "Provide a clear, concise, and comprehensive summary of the following text. CRITICAL RULE: Automatically detect the exact language of the input text, and write the summary in that exact same language (if the input text is in Urdu, write the summary in Urdu; if in English, write in English; if in Hindi, write in Hindi; strictly match whatever language the input text is in): " .. currentText
            callGeminiAPI(apiKey, modelName, prompt, "You are an expert summarizer. You must strictly output the summary in the exact same language as the input text.", function(res)
              if res then
                saveAIText(res)
                setTextBack(res)
                service.speak("Summary generated successfully")
              end
            end)
          end
        }, 1000)
      else
        Toast.makeText(service, "No text found in edit box!", Toast.LENGTH_SHORT).show()
      end
      
    elseif pos == 3 then
      if currentText ~= "" then
        speakDelayed("Writing poetry, please wait")
        
        Handler(Looper.getMainLooper()).postDelayed(Runnable{
          run = function()
            local apiKey = getGeminiApiKey()
            local modelName = getSelectedModel()
            local prompt = "Convert the following thoughts or text into a beautiful, engaging, and artistic poetic/shairi format while keeping the core message. Return ONLY the poetry text. Do NOT include any conversational intro, greetings, comments, or notes: " .. currentText
            callGeminiAPI(apiKey, modelName, prompt, "You are an expert poet and shairi writer. Return ONLY the raw poetry text with no conversational filler, comments, or intro.", function(res)
              if res then
                saveAIText(res)
                setTextBack(res)
                service.speak("Poetry generated successfully")
              end
            end)
          end
        }, 1000)
      else
        Toast.makeText(service, "No text found in edit box!", Toast.LENGTH_SHORT).show()
      end
      
    elseif pos == 4 then
      if currentText ~= "" then
        speakDelayed("Converting Roman text, please wait")
        
        Handler(Looper.getMainLooper()).postDelayed(Runnable{
          run = function()
            local apiKey = getGeminiApiKey()
            local modelName = getSelectedModel()
            local universalRomanPrompt = [[Analyze the input Roman/transliterated text carefully to determine its intended target language (English, Urdu, Hindi, Punjabi, Arabic, etc.).
Convert it accurately into proper, clean, grammatically correct script of that intended language.
Examples:
- If Roman Urdu ("Kaise ho"), convert to Urdu script ("کیسے ہو").
- If Roman/Urdu-written English ("ہو ار یو" or "how are you"), convert to proper English script ("How are you").
- If Roman Hindi/Punjabi/Arabic, convert to their respective proper native scripts.
Output ONLY the final clean converted text without any extra notes, explanations, or greetings.]]
            callGeminiAPI(apiKey, modelName, currentText, universalRomanPrompt, function(res)
              if res then
                saveAIText(res)
                setTextBack(res)
                service.speak("Text converted successfully")
              end
            end)
          end
        }, 1000)
      else
        Toast.makeText(service, "No text found in edit box!", Toast.LENGTH_SHORT).show()
      end
      
    elseif pos == 5 then
      if currentText ~= "" then
        speakDelayed("Extracting data, please wait")
        
        Handler(Looper.getMainLooper()).postDelayed(Runnable{
          run = function()
            local apiKey = getGeminiApiKey()
            local modelName = getSelectedModel()
            local otpStructuredPrompt = [[Extract any link, email address, OTP, verification code, or phone number from the given text.
CRITICAL RULES:
1. Return ONLY the raw, clean extracted data value (such as the email address, link, OTP digits, or phone number).
2. Strictly DO NOT include any headings, labels, explanations, intros, extra announcements, or placeholder texts.
3. If multiple values are found, output them cleanly separated. Return pure data only with no extra text.]]
            callGeminiAPI(apiKey, modelName, currentText, otpStructuredPrompt, function(res)
              if res then
                saveAIText(res)
                setTextBack(res)
                service.speak("Data extracted successfully")
              end
            end)
          end
        }, 1000)
      else
        Toast.makeText(service, "No text found in edit box!", Toast.LENGTH_SHORT).show()
      end
      
    elseif pos == 6 then
      showMyDialog()
    end
  end)
  
  container.addView(list, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1.0))
  
  local backBtn = Button(service)
  backBtn.setText("GO BACK")
  backBtn.setOnClickListener(function() unregisterDialog(dlg); dlg.dismiss() end)
  container.addView(backBtn)
  
  dlg.setView(container)
  dlg.show()
end

local function chooseLanguage()
  local langs = {"Urdu (Pakistan)", "English (US)", "Hindi (India)", "Punjabi (Pakistan)", "Arabic"}
  local codes = {"ur-PK", "en-US", "hi-IN", "pa-PK", "ar-SA"}
  
  local dlg = LuaDialog()
  registerDialog(dlg)
  dlg.setTitle("Select Option")
  
  local container = LinearLayout(service)
  container.setOrientation(1)
  
  local list = ListView(service)
  local adapter = ArrayAdapter(service, android.R.layout.simple_list_item_1, langs)
  list.setAdapter(adapter)
  
  container.addView(list, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1.0))
  
  local mainMenuBtn = Button(service)
  mainMenuBtn.setText("Go to Main Menu")
  mainMenuBtn.setOnClickListener(function()
    unregisterDialog(dlg)
    dlg.dismiss()
    showMyDialog()
  end)
  container.addView(mainMenuBtn)
  
  list.setOnItemClickListener(function(parent, v, pos, id)
    unregisterDialog(dlg)
    dlg.dismiss()
    if isTranslationEnabled() then
      local tDlg = LuaDialog()
      registerDialog(tDlg)
      tDlg.setTitle("Translate to?")
      local tList = ListView(service)
      local transLangs = {"Urdu", "English", "Hindi", "Punjabi", "Arabic"}
      tList.setAdapter(ArrayAdapter(service, android.R.layout.simple_list_item_1, transLangs))
      tList.setOnItemClickListener(function(p, v, p2, i)
        unregisterDialog(tDlg)
        tDlg.dismiss()
        startVoiceTyping(codes[pos+1], transLangs[p2+1])
      end)
      tDlg.setView(tList)
      tDlg.show()
    else
      startVoiceTyping(codes[pos+1], nil)
    end
  end)
  
  dlg.setView(container)
  dlg.show()
end

checkUpdate(false)

local hasEditField = (editText ~= nil) or (global_node and (global_node.isEditable() or global_node.getClassName() == "android.widget.EditText"))

if hasEditField then
  local autoStart = aiPrefs.getBoolean("auto_start_enabled", true)
  if autoStart then
    local defaultLang = getDefaultLanguage()
    if defaultLang == "Auto" or defaultLang == "Manual Select" then
      chooseLanguage()
    else
      startVoiceTyping(defaultLang, nil)
    end
  else
    showQuickMenu()
  end
else
  showMyDialog()
end