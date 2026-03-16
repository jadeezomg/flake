# Pins and folders (skifli format). Updated by sync_caya_from_session.py.
{...}: let
  spaces = (import ./spaces.nix {}).spaces;
in {
  pinsForce = true;
  pins = {
    "Inbox - jonas.hippauf@getcaya.com - Caya GmbH Mail" = {
      id = "211a8151-8641-4d57-9867-22df224deee4";
      url = "https://mail.google.com/mail/u/0/#inbox";
      isEssential = true;
      position = 101;
    };
    "Caya GmbH - Calendar - Week of March 2, 2026" = {
      id = "fa0014a7-52fd-4914-91e9-a359dfe795d6";
      url = "https://calendar.google.com/calendar/u/0/r";
      isEssential = true;
      position = 102;
    };
    "Google Meet" = {
      id = "7b9509c2-259b-4fd4-b7a7-8b211462c258";
      url = "https://meet.google.com/landing";
      isEssential = true;
      position = 103;
    };
    "0/2 loaded · Dashboard · Metabase" = {
      id = "a26a3cd9-942a-4dff-89c9-f040930bf95a";
      url = "https://metabase.caya.com/dashboard/122-pam-dashboard?customer&e-mail&id&tab=7-customer";
      isEssential = true;
      position = 104;
    };
    "Google Gemini" = {
      id = "abafbad4-2327-4310-9518-c2b3d7f4b8d9";
      url = "https://gemini.google.com/app";
      isEssential = true;
      position = 105;
    };
    "Sprints" = {
      id = "cb3f6ca6-1b09-4217-8a72-0dfeaee57dc1";
      url = "https://one.zoho.eu/zohoone/cayagmbh/home/cxapp/sprints/workspace/cayagmbh?frameorigin=https%3A%2F%2Fone.zoho.eu#projects";
      isEssential = true;
      position = 106;
    };
    "Projects | Caya Document Automation" = {
      id = "9b634da7-3a59-4400-8173-53c230afe29f";
      url = "https://app.eu.workato.com/?fid=projects";
      isEssential = true;
      position = 107;
    };
    "Caya" = {
      id = "efa63893-9a28-4e0c-ab7e-7eb678a17d65";
      url = "https://github.com/AMN-DATA";
      isEssential = true;
      position = 108;
    };
    "Dev Env" = {
      id = "{1772811911012-80}";
      workspace = spaces."Development".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1000;
    };
    "Magic" = {
      id = "{1772811910792-66}";
      workspace = spaces."Solutions".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1001;
    };
    "Automat" = {
      id = "{1772811910849-71}";
      workspace = spaces."Solutions".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1002;
    };
    "Reports" = {
      id = "{1772811910929-76}";
      workspace = spaces."Solutions".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1003;
    };
    "Sheets" = {
      id = "{1772811910969-69}";
      workspace = spaces."Solutions".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1004;
    };
    "Ops Sheets" = {
      id = "{1772811910818-8}";
      workspace = spaces."Operations".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1005;
    };
    "Forwards" = {
      id = "{1772811910906-87}";
      workspace = spaces."Operations".id;
      isGroup = true;
      isFolderCollapsed = true;
      editedTitle = true;
      position = 1006;
    };
    "Mailroom" = {
      id = "f5579d20-9585-421b-8971-7d2e45c102ab";
      url = "https://mailroom.usecaya.com/app/sources";
      workspace = spaces."Operations".id;
      isEssential = false;
      position = 201;
    };
    "Caya_1" = {
      id = "9f535ad3-889c-4ed1-bcc6-63516e64e848";
      url = "https://metabase.caya.com/dashboard/107-onboard";
      workspace = spaces."Operations".id;
      isEssential = false;
      position = 202;
    };
    "Kundentabelle - Google Sheets" = {
      id = "6810d957-da5a-4dc8-8a00-d1e80db174ef";
      url = "https://docs.google.com/spreadsheets/d/1RJ7n5ZZaLlrpHbgfVd2mODOPh2F4nJhe2VGlYuIKCE4/edit?gid=266221096#gid=266221096";
      workspace = spaces."Operations".id;
      isEssential = false;
      position = 203;
      folderParentId = "{1772811910818-8}";
    };
    "NSA_Bot2 - Google Sheets" = {
      id = "6a5bf904-14a5-4a4e-bd6a-011f036b89e7";
      url = "https://docs.google.com/spreadsheets/d/1jh-u5OD82IapcAgNbksDH_YL1CEJY-zhEe3Gcz0Oa0U/edit?pli=1&gid=1153942125#gid=1153942125";
      workspace = spaces."Operations".id;
      isEssential = false;
      position = 204;
      folderParentId = "{1772811910818-8}";
    };
    "Einzurichtende NSA - Google Sheets" = {
      id = "55f55cd5-22c8-4e2b-a07e-eed44a192acb";
      url = "https://docs.google.com/spreadsheets/d/16sfo_z2uQ0XdUElxgmCJmTqQCCpmENbA3vDLQoOYbwk/edit?gid=2127352351#gid=2127352351";
      workspace = spaces."Operations".id;
      isEssential = false;
      position = 205;
      folderParentId = "{1772811910818-8}";
    };
    "FRAUDSTER CHECK - Google Sheets" = {
      id = "2c66376f-2fd7-480a-b1ad-7a1c19d6d224";
      url = "https://docs.google.com/spreadsheets/d/152PTHmmLH2-uW8U5gREt8QFSwo7F0O6WU02JLE4Q1Wg/edit?gid=1305043741#gid=1305043741";
      workspace = spaces."Operations".id;
      isEssential = false;
      position = 206;
      folderParentId = "{1772811910818-8}";
    };
    "SQL_customerdata - Google Sheets" = {
      id = "e266709f-630e-4be7-973a-e355d58489d6";
      url = "https://docs.google.com/spreadsheets/d/1uFogl7zNtveVFyaVDMos4k1KWdztp_YbdSv4bPDJM2Q/edit?gid=0#gid=0";
      workspace = spaces."Operations".id;
      isEssential = false;
      position = 207;
      folderParentId = "{1772811910818-8}";
    };
    "Gmail" = {
      id = "1753a288-78a0-4c5e-818d-609d0ee01da4";
      url = "https://accounts.google.com/v3/signin/confirmidentifier?authuser=0&continue=https%3A%2F%2Fmail.google.com%2Fmail%2Fu%2F0%2F&dsh=S-1808202172%3A1772835813530803&emr=1&followup=https%3A%2F%2Fmail.google.com%2Fmail%2Fu%2F0%2F&ifkv=ASfE1-qx_GiuPEyNjRUmwUNJc1i_5ur27PLDay4xBTTDnvXGA5NzUaT209XJ5dzM1FWhvZiiZAyuqw&osid=1&passive=1209600&service=mail&flowName=GlifWebSignIn&flowEntry=ServiceLogin#inbox";
      workspace = spaces."Operations".id;
      isEssential = false;
      position = 208;
      folderParentId = "{1772811910906-87}";
      container = 2;
    };
    "Deutschepost" = {
      id = "777a1773-d886-4cd8-b29d-c123a681cdb8";
      url = "https://shop.deutschepost.de/";
      workspace = spaces."Operations".id;
      isEssential = false;
      position = 209;
      folderParentId = "{1772811910906-87}";
      container = 2;
    };
    "Caya Document Cockpit" = {
      id = "a8b253c6-8547-4e50-a15f-29af9190bba5";
      url = "https://app.caya.com/login";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 210;
    };
    "Caya Document Cockpit_1" = {
      id = "3e19e5ae-f067-4c62-8d03-d996121f3e28";
      url = "https://app.caya.com/login/magic";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 211;
      folderParentId = "{1772811910792-66}";
    };
    "Caya_2" = {
      id = "4895704a-b1f2-4dde-b272-47c62c56440a";
      url = "https://app.caya.com/login/magic";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 212;
      folderParentId = "{1772811910792-66}";
      container = 3;
    };
    "Google" = {
      id = "7517883f-a1f3-45d6-83ee-acea5c9fe1c7";
      url = "https://mail.google.com/mail/u/0/#inbox";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 213;
      folderParentId = "{1772811910849-71}";
      container = 1;
    };
    "Home - Google Drive" = {
      id = "8a607695-f5e3-40c8-a376-babd459be4ff";
      url = "https://drive.google.com/drive/home";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 214;
      folderParentId = "{1772811910849-71}";
      container = 1;
    };
    "AutomagicTemplate - Project Editor - App" = {
      id = "91ef20e1-a2f4-44ed-9cb9-249b463dae9a";
      url = "https://script.google.com/home/projects/1vIY1x68Obg2kPtB5tX4u8DMp0g7X0sGoG5LGnr1HjfxmrKTtbJdqaDYr/edit";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 215;
      folderParentId = "{1772811910849-71}";
      container = 1;
    };
    "AutomagicTemplateJSON - Project Editor -" = {
      id = "d44c7c37-a6a8-4a35-858f-d8eda8824ab8";
      url = "https://script.google.com/home/projects/1n8d38mlfk14p3NF1gCMP9Q97j9IP44NMV5jkEhrL78V7uaC_LLbmOob3/edit";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 216;
      folderParentId = "{1772811910849-71}";
      container = 1;
    };
    "Daily Workato Recipe failures that requi" = {
      id = "2c78472e-fb08-47e4-b5c2-219858add256";
      url = "https://metabase.caya.com/question/3316-daily-workato-recipe-failures-that-requires-follow-ups?days=1";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 217;
      folderParentId = "{1772811910929-76}";
    };
    "Caya_3" = {
      id = "25283854-6750-4402-b0ed-9ae1ab7351c4";
      url = "https://metabase.caya.com/auth/login?redirect=%2Fquestion%2F2844-active-documents-with-missing-automation-to-be-retriggered-inc-stacked-distribution%3Fdays%3D31";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 218;
      folderParentId = "{1772811910929-76}";
      container = 3;
    };
    "Google_1" = {
      id = "e6192acc-44a2-4dd6-87b2-ab6758950722";
      url = "https://docs.google.com/document/d/13qGBQ_yMl0y4H6BYgsIbm6jOL1EvFAp0_YTHmu3D00o/edit?tab=t.lsx0mf7ch6wy#heading=h.6ewrr9jlp0yl";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 219;
      folderParentId = "{1772811910969-69}";
    };
    "AUTOMATION TEAM OVERVIEW - Google Sheets" = {
      id = "cfce8516-507f-41c5-a624-b82a5f963355";
      url = "https://docs.google.com/spreadsheets/d/1ZStYBJHhUrm5MfmGGc3ry5BFHgKquKGV1fuSjFdscWs/edit?gid=0#gid=0";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 220;
      folderParentId = "{1772811910969-69}";
    };
    "Google_2" = {
      id = "31f47f33-91fa-4b5f-b700-6058cdf77097";
      url = "https://docs.google.com/spreadsheets/d/1vkz3je8w2a-xEd9-CZuT5CSszUTiJKt3Zbx1RgLGVAk/edit?gid=189094951#gid=189094951";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 221;
      folderParentId = "{1772811910969-69}";
    };
    "Google_3" = {
      id = "a59cafa3-ba55-4d0e-8b4e-d55fb2f72c1f";
      url = "https://docs.google.com/document/d/1CpUDcK4leVxk7H4-7cnVYyogIA3aJoc1X8Ook8LvYAQ/edit?tab=t.0#heading=h.xp3kdom7uoef";
      workspace = spaces."Solutions".id;
      isEssential = false;
      position = 222;
      folderParentId = "{1772811910969-69}";
    };
    "Caya Document Cockpit_2" = {
      id = "19fc4c41-aa26-4031-b8aa-e914cba7d378";
      url = "https://develop--appcayacom.netlify.app/app/folder/inbox";
      workspace = spaces."Development".id;
      isEssential = false;
      position = 223;
      folderParentId = "{1772811911012-80}";
      container = 4;
    };
    "Login to build your integrations, automa" = {
      id = "f2762615-1a4f-4b5f-b8bc-8b988e178339";
      url = "https://app.eu.workato.com/users/sign_in";
      workspace = spaces."Development".id;
      isEssential = false;
      position = 224;
      folderParentId = "{1772811911012-80}";
      container = 4;
    };
  };
}
