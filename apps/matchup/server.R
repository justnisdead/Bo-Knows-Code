##Load Libraries 
library(shiny)
library(dplyr)
library(reshape)
library(ggplot2)

#Set colors to be used:
colors <- c("#ef8a62", "#67a9cf")

## Load and clean Data
scores <- as.data.frame(read.csv("data/allscores.csv", header = TRUE))

scores <- scores[scores$Season == 2016,]

teams <- as.character(unique(scores$Team))
week <- min(scores[is.na(scores$Score), "Week"])

sim.week <- scores[scores$Week == week,]

## Aggregate Stats
team.stats <- scores[complete.cases(scores),] %>%
  group_by(Team) %>%
  summarize(avg = mean(Score),
            stdev = sd(Score))


dens.df <- data.frame(x = seq(0, 200, by = 0.1))

#############################
#### New Sim ################
#############################

games = 1000000
scores.list <- list()

for(team in teams) {
  scores.list[[team]] <- rnorm(games
                               , mean = team.stats$avg[team.stats$Team == team]
                               , sd = team.stats$stdev[team.stats$Team == team])
}

win.table <- data.frame("Team" = character(), "Wins" = numeric(), stringsAsFactors = FALSE)

for(team in teams) {
  opp <- as.character(sim.week$Opponent[sim.week$Team == team])
  wins <- sum(scores.list[[team]] > scores.list[[opp]], na.rm=TRUE)
  win.table <- rbind(win.table, data.frame(team, wins/games))
}

combined <- cbind(sim.week[,c("Team", "Opponent")], "Wins" = win.table$wins.games)

matchups <- data.frame("matchup" = paste(combined$Team, " vs ", combined$Opponent)
                       ,"teamA" = combined$Team
                       ,"teamAwin" = combined$Wins
                       ,"teamB" = combined$Opponent
                       ,"teamBwin" = 1 - combined$Wins)

matchups <- matchups[matchups$teamA %in% as.list(unique(as.data.frame(t(apply(matchups[c(2,4)], 1, sort))))[1])[[1]],]

sim.scores <- data.frame(melt(scores.list))

shinyServer(
  function(input, output) {
    
    output$week <- renderText({as.character(week)})
    
    output$var = renderUI(selectInput("matchup","Select a matchup", unique(matchups$matchup)))
    
    output$teamA <- renderText({
      as.character(matchups$teamA[matchups$matchup == input$matchup])
    })
    
    output$teamAper <- renderText({
      paste(round(matchups$teamAwin[matchups$matchup == input$matchup] * 100, 2), "%", sep = "")
    })
    
    output$teamB <- renderText({
      as.character(matchups$teamB[matchups$matchup == input$matchup])
    })
    
    output$teamBper <- renderText({
      paste(round(matchups$teamBwin[matchups$matchup == input$matchup] * 100, 2), "%", sep = "")
    })
    
    output$d.plot <- renderPlot({
      selected.matchup <- input$matchup
      teamA <- matchups$teamA[matchups$matchup == selected.matchup]
      teamB <- matchups$teamB[matchups$matchup == selected.matchup]
      
      ggplot(dens.df, aes(x)) + 
        geom_area(stat = "function",
                  fun = dnorm, 
                  fill = colors[1],
                  alpha = .5,
                  args = list(mean = team.stats$avg[team.stats$Team == teamA],
                              sd = team.stats$stdev[team.stats$Team == teamA])) +
        geom_area(stat = "function",
                  fun = dnorm,
                  fill = colors[2],
                  alpha = .5,
                  args = list(mean = team.stats$avg[team.stats$Team == teamB],
                              sd = team.stats$stdev[team.stats$Team == teamB])) +
        labs(x = "Score", y = "Density")
    })
    
    output$l.plot <- renderPlot({
      selected.matchup <- input$matchup
      teams <- c(as.character(matchups$teamA[matchups$matchup == selected.matchup]), 
                 as.character(matchups$teamB[matchups$matchup == selected.matchup]))
      
      matchup.scores <- scores[scores$Team %in% teams, c("Team", "Week", "Score")]
      
      max <- max(matchup.scores$Score, na.rm = TRUE) + 20
      min <- min(matchup.scores$Score, na.rm = TRUE) - 20
      
      ggplot(matchup.scores, aes(x = Week, y = Score, color = Team)) + 
        geom_line(size = 2, alpha = .5) + 
        ylim(min, max) + 
        scale_x_continuous(breaks = 1:week-1, limits = c(1, week-1)) +
        scale_color_manual(values = colors) +
        theme(legend.position="none")
    })
  })