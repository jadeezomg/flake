# Pins and folders (skifli format). Updated by sync_caya_from_session.py.
{...}: let
  spaces = (import ./spaces.nix {}).spaces;
in {
  pinsForce = true;
  pins = {
    "Inbox - jonas.hippauf@getcaya.com - Caya GmbH Mail" = {
      id = "ab030d96-0979-4b78-8296-f358699888c9";
      url = "https://mail.google.com/mail/u/0/#inbox";
      isEssential = true;
      position = 101;
    };
    "Caya GmbH - Calendar - Week of March 30, 2026" = {
      id = "3fcdd19c-cf1f-4add-b13a-5557d1638abf";
      url = "https://calendar.google.com/calendar/u/0/r";
      isEssential = true;
      position = 102;
    };
    "Google Meet" = {
      id = "ef4b2cba-9a2c-4978-8431-55a79e8f5e01";
      url = "https://meet.google.com/landing";
      isEssential = true;
      position = 103;
    };
    "0/2 loaded · Dashboard · Metabase" = {
      id = "52b997e2-9302-47ea-8ef2-b8a2e4c73da2";
      url = "https://metabase.caya.com/dashboard/122-pam-dashboard?customer&e-mail&id&tab=7-customer";
      isEssential = true;
      position = 104;
    };
    "Google Gemini" = {
      id = "e5715caa-2d47-45c3-a3be-55a77afc2064";
      url = "https://gemini.google.com/app";
      isEssential = true;
      position = 105;
    };
    "Sprints" = {
      id = "be8be98c-bf34-485e-b9cd-3b448240959e";
      url = "https://one.zoho.eu/zohoone/cayagmbh/home/cxapp/sprints/workspace/cayagmbh?frameorigin=https%3A%2F%2Fone.zoho.eu#projects";
      isEssential = true;
      position = 106;
    };
    "Projects | Caya Document Automation" = {
      id = "d245f84c-28ed-4b55-831a-d23c4710c847";
      url = "https://app.eu.workato.com/?fid=projects";
      isEssential = true;
      position = 107;
    };
    "Caya" = {
      id = "2914bfbb-2064-47ea-9211-5c02f446bc89";
      url = "https://github.com/AMN-DATA";
      isEssential = true;
      position = 108;
    };
    "Story | Shortcut" = {
      id = "4c3f71f3-8ef1-4722-b046-6b71f99e3322";
      url = "https://app.shortcut.com/caya/dashboard/";
      isEssential = true;
      position = 109;
    };
    "Dev Env" = {
      id = "{{1772811911012-80}}";
      workspace = spaces."Development".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1000;
    };
    "Toolbox" = {
      id = "1774867657222-23";
      workspace = spaces."Development".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1001;
    };
    "Tools" = {
      id = "1774867666645-82";
      workspace = spaces."Development".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1002;
    };
    "Website AI Tools" = {
      id = "1774867297412-79";
      workspace = spaces."Research".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1003;
    };
    "OCR -> Data Research" = {
      id = "1774866958574-54";
      workspace = spaces."Research".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1004;
    };
    "OCR -> Data Tests" = {
      id = "1774867395074-62";
      workspace = spaces."Research".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1005;
    };
    "Magic" = {
      id = "{{1772811910792-66}}";
      workspace = spaces."Solutions".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1006;
    };
    "Automat" = {
      id = "{{1772811910849-71}}";
      workspace = spaces."Solutions".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1007;
    };
    "Reports" = {
      id = "{{1772811910929-76}}";
      workspace = spaces."Solutions".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1008;
    };
    "Sheets" = {
      id = "{{1772811910969-69}}";
      workspace = spaces."Solutions".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1009;
    };
    "Ops Sheets" = {
      id = "{{1772811910818-8}}";
      workspace = spaces."Work".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1010;
    };
    "Mailroom" = {
      id = "1774867533295-57";
      workspace = spaces."Work".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1011;
    };
    "Forwards" = {
      id = "{{1772811910906-87}}";
      workspace = spaces."Work".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1012;
    };
    "Irrläufer" = {
      id = "1774867512358-0";
      workspace = spaces."Work".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1013;
    };
    "PIN" = {
      id = "1774866854440-80";
      workspace = spaces."Work".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1014;
    };
    "Stitch - Design with AI" = {
      id = "81940dcb-9df1-436e-a72a-4e706bf37298";
      url = "https://stitch.withgoogle.com/";
      workspace = spaces."Research".id;
      isEssential = false;
      position = 201;
      folderParentId = "1774867297412-79";
    };
    "Google" = {
      id = "e09e787c-ee1d-41cd-992d-b1a2babf54ba";
      url = "https://www.google.com/search?client=firefox-b-d&channel=entpr&q=Infinity-Parser%207B*";
      workspace = spaces."Research".id;
      isEssential = false;
      position = 202;
      folderParentId = "1774866958574-54";
    };
    "Welcome to Datalab - Datalab Documentati" = {
      id = "109149e9-542e-4952-a074-a0c0277980e9";
      url = "https://documentation.datalab.to/";
      workspace = spaces."Research".id;
      isEssential = false;
      position = 203;
      folderParentId = "1774866958574-54";
    };
    "Datalab" = {
      id = "ab256ebb-4053-44e3-92e7-995cb0cb97f6";
      url = "https://github.com/datalab-to";
      workspace = spaces."Research".id;
      isEssential = false;
      position = 204;
      folderParentId = "1774866958574-54";
    };
    "OlmOCR-2-7B - Google Search" = {
      id = "7c0165a0-adeb-45f7-800c-6be4cfdedb3f";
      url = "https://www.google.com/search?client=firefox-b-d&channel=entpr&q=OlmOCR-2-7B";
      workspace = spaces."Research".id;
      isEssential = false;
      position = 205;
      folderParentId = "1774866958574-54";
    };
    "Github" = {
      id = "42eda8cc-c2aa-498b-b22f-e705daf67537";
      url = "https://github.com/allenai/olmocr";
      workspace = spaces."Research".id;
      isEssential = false;
      position = 206;
      folderParentId = "1774866958574-54";
    };
    "Mistral" = {
      id = "052efde8-5550-4b7a-b049-88a669774c54";
      url = "https://docs.mistral.ai/capabilities/document_ai/basic_ocr";
      workspace = spaces."Research".id;
      isEssential = false;
      position = 207;
      folderParentId = "1774866958574-54";
    };
    "mistral ocr - Google Search" = {
      id = "adc295f0-94b6-43af-90aa-0a77793596b5";
      url = "https://www.google.com/search?client=firefox-b-d&channel=entpr&q=mistral%20ocr";
      workspace = spaces."Research".id;
      isEssential = false;
      position = 208;
      folderParentId = "1774866958574-54";
    };
    "kreuzberg ocr table extraction - Google " = {
      id = "2d12c991-079f-4552-8587-bc23df0b3edc";
      url = "https://www.google.com/search?client=firefox-b-d&channel=entpr&q=kreuzberg%20ocr%20table%20extraction";
      workspace = spaces."Research".id;
      isEssential = false;
      position = 209;
      folderParentId = "1774867395074-62";
    };
    "rabbitmq - Google Search" = {
      id = "622e7fdf-7876-4076-8dea-46ab7936bbdd";
      url = "https://www.google.com/search?client=firefox-b-d&channel=entpr&q=rabbitmq";
      workspace = spaces."Research".id;
      isEssential = false;
      position = 210;
    };
    "Caya_1" = {
      id = "2d5de53a-de24-41f9-82d9-07d1d994dd98";
      url = "https://metabase.caya.com/dashboard/107-onboard";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 211;
    };
    "Kundentabelle - Google Sheets" = {
      id = "ccd51e28-0add-4fe3-8dc1-f4a30adf809f";
      url = "https://docs.google.com/spreadsheets/d/1RJ7n5ZZaLlrpHbgfVd2mODOPh2F4nJhe2VGlYuIKCE4/edit?gid=266221096#gid=266221096";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 212;
      folderParentId = "{{1772811910818-8}}";
    };
    "NSA_Bot2 - Google Sheets" = {
      id = "c11bd45a-482a-46e3-89e9-7bfdda2c1a62";
      url = "https://docs.google.com/spreadsheets/d/1jh-u5OD82IapcAgNbksDH_YL1CEJY-zhEe3Gcz0Oa0U/edit?pli=1&gid=1153942125#gid=1153942125";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 213;
      folderParentId = "{{1772811910818-8}}";
    };
    "Einzurichtende NSA - Google Sheets" = {
      id = "afcb9af2-a3ae-44d0-9bce-83f62854715e";
      url = "https://docs.google.com/spreadsheets/d/16sfo_z2uQ0XdUElxgmCJmTqQCCpmENbA3vDLQoOYbwk/edit?gid=2127352351#gid=2127352351";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 214;
      folderParentId = "{{1772811910818-8}}";
    };
    "FRAUDSTER CHECK - Google Sheets" = {
      id = "505f108b-9c27-46a4-9dc3-d286fce04d4e";
      url = "https://docs.google.com/spreadsheets/d/152PTHmmLH2-uW8U5gREt8QFSwo7F0O6WU02JLE4Q1Wg/edit?gid=1305043741#gid=1305043741";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 215;
      folderParentId = "{{1772811910818-8}}";
    };
    "SQL_customerdata - Google Sheets" = {
      id = "5d21775d-bc50-468d-a1d0-0a5c38902784";
      url = "https://docs.google.com/spreadsheets/d/1uFogl7zNtveVFyaVDMos4k1KWdztp_YbdSv4bPDJM2Q/edit?gid=0#gid=0";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 216;
      folderParentId = "{{1772811910818-8}}";
    };
    "Mailroom_1" = {
      id = "5ab6eb94-8552-4ec1-8944-4ba1d45c8acf";
      url = "https://mailroom.usecaya.com/app/sources";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 217;
      folderParentId = "1774867533295-57";
    };
    "Caya_2" = {
      id = "2759f4f1-a7d8-4d9e-b220-a964d52c5209";
      url = "https://mailroom-api.caya.dev/";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 218;
      folderParentId = "1774867533295-57";
    };
    "Gmail" = {
      id = "60bbf5be-86f3-4487-b7b0-47a68162914b";
      url = "https://accounts.google.com/v3/signin/confirmidentifier?authuser=0&continue=https%3A%2F%2Fmail.google.com%2Fmail%2Fu%2F0%2F&dsh=S-1808202172%3A1772835813530803&emr=1&followup=https%3A%2F%2Fmail.google.com%2Fmail%2Fu%2F0%2F&ifkv=ASfE1-qx_GiuPEyNjRUmwUNJc1i_5ur27PLDay4xBTTDnvXGA5NzUaT209XJ5dzM1FWhvZiiZAyuqw&osid=1&passive=1209600&service=mail&flowName=GlifWebSignIn&flowEntry=ServiceLogin#inbox";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 219;
      folderParentId = "{{1772811910906-87}}";
      container = 2;
    };
    "Deutschepost" = {
      id = "817d4216-d995-4ef9-a988-79b5f8c259b2";
      url = "https://shop.deutschepost.de/";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 220;
      folderParentId = "{{1772811910906-87}}";
      container = 2;
    };
    "Figma" = {
      id = "18d87c19-42d9-40e5-8585-9405dddd43c6";
      url = "https://www.figma.com/board/zO9Bz7SUHTpTtlqV2RohRI/SPS-Irrl%C3%A4ufer-Prozess?node-id=0-1&p=f&t=lOByGtlYcAWpdqwL-0";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 221;
      folderParentId = "1774867512358-0";
    };
    "PIN_Vollmacht - Google Drive" = {
      id = "f28a1021-fc6a-4cb3-8f86-8ced25cd3e11";
      url = "https://drive.google.com/drive/folders/16iPu_tedJ1mUrRrnske559GVPE7sK9Kl";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 222;
      folderParentId = "1774866854440-80";
    };
    "Caya_3" = {
      id = "9737e095-a34a-467b-880b-e7892e62f859";
      url = "https://metabase.caya.com/question/2001-check-pin-forward-renewing-active";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 223;
      folderParentId = "1774866854440-80";
    };
    "PIN Process - Google Docs" = {
      id = "04b2a4d6-1051-4843-abce-0adde39108d3";
      url = "https://docs.google.com/document/d/1kaOCfBWJY4k4-micsvGSoUayv-RRBQ4siJtQeAqIDSc/edit?tab=t.0";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 224;
      folderParentId = "1774866854440-80";
    };
    "Caya Document Cockpit" = {
      id = "2fa8ba5b-1f55-476e-9beb-6fef273e2ff8";
      url = "https://app.caya.com/login";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 225;
    };
    "Caya Document Cockpit_1" = {
      id = "ac8790f2-7ed3-4ceb-be62-06c703306b77";
      url = "https://app.caya.com/login/magic";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 226;
      folderParentId = "{{1772811910792-66}}";
    };
    "Caya_2_1" = {
      id = "d5110fd9-2b4d-40e2-b2cc-2331f356cfab";
      url = "https://app.caya.com/login/magic";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 227;
      folderParentId = "{{1772811910792-66}}";
      container = 3;
    };
    "Google_1" = {
      id = "faf6f26f-f3e9-4b38-be43-635f2e51adb1";
      url = "https://mail.google.com/mail/u/0/#inbox";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 228;
      folderParentId = "{{1772811910849-71}}";
      container = 1;
    };
    "Home - Google Drive" = {
      id = "dda98db1-8bac-4480-a329-7a0a49154192";
      url = "https://drive.google.com/drive/home";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 229;
      folderParentId = "{{1772811910849-71}}";
      container = 1;
    };
    "AutomagicTemplate - Project Editor - App" = {
      id = "546b37f7-9f3b-4bac-8a73-6effacd245aa";
      url = "https://script.google.com/home/projects/1vIY1x68Obg2kPtB5tX4u8DMp0g7X0sGoG5LGnr1HjfxmrKTtbJdqaDYr/edit";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 230;
      folderParentId = "{{1772811910849-71}}";
      container = 1;
    };
    "AutomagicTemplateJSON - Project Editor -" = {
      id = "5312ffeb-25ac-4a64-a896-2ffa854e8153";
      url = "https://script.google.com/home/projects/1n8d38mlfk14p3NF1gCMP9Q97j9IP44NMV5jkEhrL78V7uaC_LLbmOob3/edit";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 231;
      folderParentId = "{{1772811910849-71}}";
      container = 1;
    };
    "Daily Workato Recipe failures that requi" = {
      id = "a3fe10f1-44f2-440f-bf97-0b699946cdc9";
      url = "https://metabase.caya.com/question/3316-daily-workato-recipe-failures-that-requires-follow-ups?days=1";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 232;
      folderParentId = "{{1772811910929-76}}";
    };
    "Caya_3_1" = {
      id = "9c16662c-5fa8-4f7d-a200-5d3195d1b5b8";
      url = "https://metabase.caya.com/auth/login?redirect=%2Fquestion%2F2844-active-documents-with-missing-automation-to-be-retriggered-inc-stacked-distribution%3Fdays%3D31";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 233;
      folderParentId = "{{1772811910929-76}}";
      container = 3;
    };
    "Google_1_1" = {
      id = "19c26bb6-e275-418b-a66b-5664c4b25b10";
      url = "https://docs.google.com/document/d/13qGBQ_yMl0y4H6BYgsIbm6jOL1EvFAp0_YTHmu3D00o/edit?tab=t.lsx0mf7ch6wy#heading=h.6ewrr9jlp0yl";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 234;
      folderParentId = "{{1772811910969-69}}";
    };
    "AUTOMATION TEAM OVERVIEW - Google Sheets" = {
      id = "562ffc16-03cc-41cf-ab9c-fa02cded5af9";
      url = "https://docs.google.com/spreadsheets/d/1ZStYBJHhUrm5MfmGGc3ry5BFHgKquKGV1fuSjFdscWs/edit?gid=0#gid=0";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 235;
      folderParentId = "{{1772811910969-69}}";
    };
    "Google_2" = {
      id = "5eadee88-9bd6-4a00-8b55-972d3626ed0d";
      url = "https://docs.google.com/spreadsheets/d/1vkz3je8w2a-xEd9-CZuT5CSszUTiJKt3Zbx1RgLGVAk/edit?gid=189094951#gid=189094951";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 236;
      folderParentId = "{{1772811910969-69}}";
    };
    "Google_3" = {
      id = "893cdfff-a120-49ba-a28a-2ac4e32eb6b7";
      url = "https://docs.google.com/document/d/1CpUDcK4leVxk7H4-7cnVYyogIA3aJoc1X8Ook8LvYAQ/edit?tab=t.0#heading=h.xp3kdom7uoef";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 237;
      folderParentId = "{{1772811910969-69}}";
    };
    "Caya Document Cockpit_2" = {
      id = "4d8f500b-369b-417f-88f6-22b565605a1e";
      url = "https://develop--appcayacom.netlify.app/app/folder/inbox";
      workspace = spaces."Development".id;
      isEssential = false;
      position = 238;
      folderParentId = "{{1772811911012-80}}";
      container = 4;
    };
    "Login to build your integrations, automa" = {
      id = "c846fe44-3142-4f24-b733-4e6035682435";
      url = "https://app.eu.workato.com/users/sign_in";
      workspace = spaces."Development".id;
      isEssential = false;
      position = 239;
      folderParentId = "{{1772811911012-80}}";
      container = 4;
    };
    "Tools-dev" = {
      id = "8a68680f-31c1-4757-ae7e-70de181f6ce1";
      url = "https://www.tools-dev.com/en/category/encoding/";
      workspace = spaces."Development".id;
      isEssential = false;
      position = 240;
      folderParentId = "1774867657222-23";
    };
    "Github_1" = {
      id = "55765182-8ec5-40db-90e5-bf7cbc098e8d";
      url = "https://github.com/Vijay-Duke/devtoolbox?tab=readme-ov-file";
      workspace = spaces."Development".id;
      isEssential = false;
      position = 241;
      folderParentId = "1774867657222-23";
    };
    "resterm - Google Search" = {
      id = "8994ef58-225b-471d-a5b2-432b1b9dd2cd";
      url = "https://www.google.com/search?client=firefox-b-d&channel=entpr&q=resterm";
      workspace = spaces."Development".id;
      isEssential = false;
      position = 242;
      folderParentId = "1774867666645-82";
    };
    "Github_2" = {
      id = "a8472d20-47a9-46f6-99ed-1ea9c39c5787";
      url = "https://github.com/aleiepure/devtoolbox?tab=readme-ov-file";
      workspace = spaces."Development".id;
      isEssential = false;
      position = 243;
      folderParentId = "1774867666645-82";
    };
  };
}
