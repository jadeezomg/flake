# Pins and folders (skifli format). Updated by sync_caya_from_session.py.
{ ... }:
let
  spaces = (import ./spaces.nix {}).spaces;
in
{
  pinsForce = true;
  pins = {
    "Inbox - jonas.hippauf@getcaya.com - Caya GmbH Mail" = {
      id = "d89cebc5-b4a0-458d-8d2c-e1322aadf272";
      url = "https://mail.google.com/mail/u/0/#inbox";
      isEssential = true;
      position = 101;
    };
    "Caya GmbH - Calendar - Week of March 2, 2026" = {
      id = "488839fb-daf4-442a-a4c8-9fff0c5faa7d";
      url = "https://calendar.google.com/calendar/u/0/r";
      isEssential = true;
      position = 102;
    };
    "Google Meet" = {
      id = "4654eae0-035c-4f30-b29d-1ee3016df709";
      url = "https://meet.google.com/landing";
      isEssential = true;
      position = 103;
    };
    "0/2 loaded · Dashboard · Metabase" = {
      id = "8c137d7f-115f-4207-aa37-32a6bcbcf6f1";
      url = "https://metabase.caya.com/dashboard/122-pam-dashboard?customer&e-mail&id&tab=7-customer";
      isEssential = true;
      position = 104;
    };
    "Google Gemini" = {
      id = "3003c9ce-2fb4-4652-ae92-b02b7534022d";
      url = "https://gemini.google.com/app";
      isEssential = true;
      position = 105;
    };
    "Sprints" = {
      id = "ebc08249-4bda-4a7a-bea3-0c7c1d045ccf";
      url = "https://one.zoho.eu/zohoone/cayagmbh/home/cxapp/sprints/workspace/cayagmbh?frameorigin=https%3A%2F%2Fone.zoho.eu#projects";
      isEssential = true;
      position = 106;
    };
    "Projects | Caya Document Automation" = {
      id = "d9119166-ea13-4ce1-b5e2-85bb16f3e7b9";
      url = "https://app.eu.workato.com/?fid=projects";
      isEssential = true;
      position = 107;
    };
    "Caya" = {
      id = "d27c0619-92b5-4216-9f09-1c9ae376dc1e";
      url = "https://github.com/AMN-DATA";
      isEssential = true;
      position = 108;
    };
    "Dev Env" = {
      id = "1772811911012-80";
      workspace = spaces."Development".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1000;
    };
    "Magic" = {
      id = "1772811910792-66";
      workspace = spaces."Solutions".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1001;
    };
    "Automat" = {
      id = "1772811910849-71";
      workspace = spaces."Solutions".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1002;
    };
    "Reports" = {
      id = "1772811910929-76";
      workspace = spaces."Solutions".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1003;
    };
    "Sheets" = {
      id = "1772811910969-69";
      workspace = spaces."Solutions".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1004;
    };
    "Sheets_1" = {
      id = "1772811910818-8";
      workspace = spaces."Work".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1005;
    };
    "Forwards" = {
      id = "1772811910906-87";
      workspace = spaces."Work".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1006;
    };
    "Mailroom" = {
      id = "fdcb3387-d62f-43aa-9348-b99e97d55d01";
      url = "https://mailroom.usecaya.com/app/sources";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 201;
    };
    "Caya_1" = {
      id = "c9847f7c-538f-480e-ba7c-ab8d48e2e5c8";
      url = "https://metabase.caya.com/dashboard/107-onboard";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 202;
    };
    "Kundentabelle - Google Sheets" = {
      id = "3c78f037-77e1-475f-8b45-4b577c1b90df";
      url = "https://docs.google.com/spreadsheets/d/1RJ7n5ZZaLlrpHbgfVd2mODOPh2F4nJhe2VGlYuIKCE4/edit?gid=266221096#gid=266221096";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 203;
      folderParentId = "1772811910818-8";
    };
    "NSA_Bot2 - Google Sheets" = {
      id = "3254b515-9bfe-4d34-b7e5-6266fc019f56";
      url = "https://docs.google.com/spreadsheets/d/1jh-u5OD82IapcAgNbksDH_YL1CEJY-zhEe3Gcz0Oa0U/edit?pli=1&gid=1153942125#gid=1153942125";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 204;
      folderParentId = "1772811910818-8";
    };
    "Einzurichtende NSA - Google Sheets" = {
      id = "bf316e5e-717d-460a-b0cc-6032ddfa229a";
      url = "https://docs.google.com/spreadsheets/d/16sfo_z2uQ0XdUElxgmCJmTqQCCpmENbA3vDLQoOYbwk/edit?gid=2127352351#gid=2127352351";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 205;
      folderParentId = "1772811910818-8";
    };
    "FRAUDSTER CHECK - Google Sheets" = {
      id = "4bbf1bfa-6795-4bf0-a90c-ce9633b49673";
      url = "https://docs.google.com/spreadsheets/d/152PTHmmLH2-uW8U5gREt8QFSwo7F0O6WU02JLE4Q1Wg/edit?gid=1305043741#gid=1305043741";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 206;
      folderParentId = "1772811910818-8";
    };
    "SQL_customerdata - Google Sheets" = {
      id = "ac511937-1fd6-4fa6-a1de-d6844b984754";
      url = "https://docs.google.com/spreadsheets/d/1uFogl7zNtveVFyaVDMos4k1KWdztp_YbdSv4bPDJM2Q/edit?gid=0#gid=0";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 207;
      folderParentId = "1772811910818-8";
    };
    "Deutschepost" = {
      id = "7431f4e4-4c1d-4140-b80b-359a0234b950";
      url = "https://shop.deutschepost.de/";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 208;
      folderParentId = "1772811910906-87";
    };
    "Google" = {
      id = "3163def9-2d30-4dcc-95e7-4782ea3a11f1";
      url = "https://mail.google.com/mail/u/0/#inbox";
      workspace = spaces."Work".id;
      isEssential = false;
      position = 209;
      folderParentId = "1772811910906-87";
    };
    "Caya Document Cockpit" = {
      id = "00d857d2-3927-4998-814f-d63eb9c900e2";
      url = "https://app.caya.com/login";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 210;
    };
    "Caya Document Cockpit_1" = {
      id = "15d4fdb5-2e18-47f0-9dd2-fe40af89a3cd";
      url = "https://app.caya.com/login/magic";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 211;
      folderParentId = "1772811910792-66";
    };
    "Caya Document Cockpit_2" = {
      id = "95b8296f-77cf-4c42-8ca8-7b4ed673010f";
      url = "https://app.caya.com/login/magic";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 212;
      folderParentId = "1772811910792-66";
    };
    "Google_1" = {
      id = "a1c67024-ca00-4c30-9890-6b024ab946d0";
      url = "https://mail.google.com/mail/u/0/#inbox";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 213;
      folderParentId = "1772811910849-71";
    };
    "Google Drive" = {
      id = "82710431-c98b-4d1b-bd02-df51e60bbc93";
      url = "https://drive.google.com/drive/?pli=1";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 214;
      folderParentId = "1772811910849-71";
    };
    "AutomagicTemplate - Project Editor - App" = {
      id = "0a0d71cb-9ba9-4e09-9751-984c5d954cc0";
      url = "https://script.google.com/home/projects/1vIY1x68Obg2kPtB5tX4u8DMp0g7X0sGoG5LGnr1HjfxmrKTtbJdqaDYr/edit";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 215;
      folderParentId = "1772811910849-71";
    };
    "AutomagicTemplateJSON - Project Editor -" = {
      id = "54819ac9-fea4-46a3-a9d0-f0224892f24d";
      url = "https://script.google.com/home/projects/1n8d38mlfk14p3NF1gCMP9Q97j9IP44NMV5jkEhrL78V7uaC_LLbmOob3/edit";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 216;
      folderParentId = "1772811910849-71";
    };
    "Caya_2" = {
      id = "2c78f3de-7f8c-43d5-adce-021952cbd300";
      url = "https://metabase.caya.com/question/3316-daily-workato-recipe-failures-that-requires-follow-ups?days=1";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 217;
      folderParentId = "1772811910929-76";
    };
    "Caya_3" = {
      id = "3ed90475-64b9-4d33-8139-ef60b7bed1de";
      url = "https://metabase.caya.com/question/2844-active-documents-with-missing-automation-to-be-retriggered-inc-stacked-distribution?days=31";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 218;
      folderParentId = "1772811910929-76";
    };
    "Google_2" = {
      id = "156333d7-e0cf-4ba3-b1e5-938ca45a32d1";
      url = "https://docs.google.com/document/d/13qGBQ_yMl0y4H6BYgsIbm6jOL1EvFAp0_YTHmu3D00o/edit?tab=t.lsx0mf7ch6wy#heading=h.6ewrr9jlp0yl";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 219;
      folderParentId = "1772811910969-69";
    };
    "AUTOMATION TEAM OVERVIEW - Google Sheets" = {
      id = "08a70a22-ffa6-4b4c-9e7d-325cd608e856";
      url = "https://docs.google.com/spreadsheets/d/1ZStYBJHhUrm5MfmGGc3ry5BFHgKquKGV1fuSjFdscWs/edit?gid=0#gid=0";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 220;
      folderParentId = "1772811910969-69";
    };
    "Google_3" = {
      id = "f314da80-1a80-4470-a0bb-afa00e0a4043";
      url = "https://docs.google.com/spreadsheets/d/1vkz3je8w2a-xEd9-CZuT5CSszUTiJKt3Zbx1RgLGVAk/edit?gid=189094951#gid=189094951";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 221;
      folderParentId = "1772811910969-69";
    };
    "Untitled document - Google Docs" = {
      id = "4562ea4e-0443-4ecf-9c1d-823f54d4497c";
      url = "https://docs.google.com/document/d/1CpUDcK4leVxk7H4-7cnVYyogIA3aJoc1X8Ook8LvYAQ/edit?tab=t.0#heading=h.xp3kdom7uoef";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 222;
      folderParentId = "1772811910969-69";
    };
    "Caya Document Cockpit_3" = {
      id = "091cf855-15ea-42fd-b3d4-6620aff846ab";
      url = "https://develop--appcayacom.netlify.app/login";
      workspace = spaces."Development".id;
      isEssential = false;
      position = 223;
      folderParentId = "1772811911012-80";
    };
    "Login to build your integrations, automa" = {
      id = "1269ac56-a771-4844-b85a-fafebbcf95d1";
      url = "https://app.eu.workato.com/users/sign_in";
      workspace = spaces."Development".id;
      isEssential = false;
      position = 224;
      folderParentId = "1772811911012-80";
    };
  };
}
