import { defineConfig } from "vitepress";

export default defineConfig({
  title: "CC Bearing Turret",
  description:
    "ComputerCraft aiming for Create Simulated gun bearings on Amazeballs",
  cleanUrls: true,
  themeConfig: {
    nav: [
      { text: "Home", link: "/" },
      { text: "Functions", link: "/functions/" },
      { text: "Ainterface", link: "/ainterface" },
      { text: "Plan", link: "/plan" },
    ],
    sidebar: [
      {
        text: "Workspace",
        items: [
          { text: "Home", link: "/" },
          { text: "Plan", link: "/plan" },
          { text: "Nickify Board", link: "/nickify/board" },
          { text: "Topics", link: "/topics" },
          { text: "Ainterface", link: "/ainterface" },
          { text: "Pseudocode", link: "/pseudocode/hierarchy" },
        ],
      },
      {
        text: "Research",
        items: [
          { text: "1 Overview", link: "/research/1/overview" },
          { text: "1 Paper", link: "/research/1/paper" },
          { text: "2 Overview", link: "/research/2/overview" },
          { text: "2 Paper", link: "/research/2/paper" },
          { text: "3 Overview", link: "/research/3/overview" },
          { text: "3 Paper", link: "/research/3/paper" },
          { text: "4 Overview", link: "/research/4/overview" },
          { text: "4 Paper", link: "/research/4/paper" },
          { text: "5 Overview", link: "/research/5/overview" },
          { text: "5 Paper", link: "/research/5/paper" },
          { text: "6 Overview", link: "/research/6/overview" },
          { text: "6 Paper", link: "/research/6/paper" },
        ],
      },
      {
        text: "Functions",
        items: [
          { text: "Catalog", link: "/functions/" },
          { text: "Read Radar Tracks", link: "/functions/basic/read-radar-tracks" },
          {
            text: "Read Radar Tracks Technical",
            link: "/functions/basic/read-radar-tracks.technical",
          },
          {
            text: "Read Swivel Bearing Angle",
            link: "/functions/basic/read-swivel-bearing-angle",
          },
          {
            text: "Read Swivel Bearing Angle Technical",
            link: "/functions/basic/read-swivel-bearing-angle.technical",
          },
          {
            text: "Set Electric Motor Speed",
            link: "/functions/basic/set-electric-motor-speed",
          },
          {
            text: "Set Electric Motor Speed Technical",
            link: "/functions/basic/set-electric-motor-speed.technical",
          },
          {
            text: "Fire Rotating Barrel",
            link: "/functions/basic/fire-rotating-barrel",
          },
          {
            text: "Fire Rotating Barrel Technical",
            link: "/functions/basic/fire-rotating-barrel.technical",
          },
          {
            text: "Rotate Bearing Toward Angle",
            link: "/functions/advanced/rotate-bearing-toward-angle",
          },
          {
            text: "Rotate Bearing Toward Angle Technical",
            link: "/functions/advanced/rotate-bearing-toward-angle.technical",
          },
          {
            text: "Aim Turret At Target",
            link: "/functions/advanced/aim-turret-at-target",
          },
          {
            text: "Aim Turret At Target Technical",
            link: "/functions/advanced/aim-turret-at-target.technical",
          },
        ],
      },
    ],
    search: {
      provider: "local",
    },
    outline: {
      level: [2, 3],
    },
  },
});
