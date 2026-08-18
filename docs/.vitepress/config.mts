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
