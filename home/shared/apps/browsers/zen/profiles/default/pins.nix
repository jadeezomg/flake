# Pins and folders (NixOS default profile). Updated by sync_caya_from_session.py on NixOS.
{...}: let
  spaces = import ./spaces.nix {};
in {
  pinsForce = true;
  pins = {
    "Proton Mail" = {
      id = "5855f1ce-a12a-4065-8965-dd1a71f76a5c";
      url = "https://mail.proton.me";
      position = 101;
      isEssential = true;
    };
    "YouTube" = {
      id = "5ad224b2-5596-4268-b492-d7a781ea7c8e";
      url = "https://www.youtube.com";
      position = 102;
      isEssential = true;
    };
    "Discord" = {
      id = "87e179f9-4f46-4aeb-bc0f-fca09b5fff23";
      url = "https://discord.com";
      position = 103;
      isEssential = true;
    };
    "Reddit" = {
      id = "eaf54047-7d5f-423e-b695-c794b3df0e82";
      url = "https://www.reddit.com";
      position = 104;
      isEssential = true;
    };
    "Bluesky" = {
      id = "f78b129b-b4c8-4de1-9c6b-fd8254efde8a";
      url = "https://bsky.app";
      position = 105;
      isEssential = true;
    };
    "WhatsApp Web" = {
      id = "5117b79f-7b69-4763-a804-683b413c9611";
      url = "https://web.whatsapp.com/";
      position = 106;
      isEssential = true;
    };
    "GitHub" = {
      id = "27762ade-30f6-4895-b348-b0410e9d858b";
      url = "https://github.com";
      position = 107;
      isEssential = true;
    };
    "Le Chat" = {
      id = "9760b4d1-ab39-43d7-8fba-3b8232b04ad1";
      url = "https://chat.mistral.ai";
      position = 108;
      isEssential = true;
    };
    "jadee-server" = {
      id = "6a7a0766-9e1d-48a3-a14b-42a79ba85bc0";
      url = "http://jadee-server";
      position = 109;
      isEssential = true;
    };
  };
}
