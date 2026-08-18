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
          { text: "8 Overview", link: "/research/8/overview" },
          { text: "8 Paper", link: "/research/8/paper" },
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
            text: "Engage Simulated Bearing Turret",
            link: "/functions/high-level/engage-simulated-bearing-turret",
          },
          {
            text: "Engage Simulated Bearing Turret Technical",
            link: "/functions/high-level/engage-simulated-bearing-turret.technical",
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
