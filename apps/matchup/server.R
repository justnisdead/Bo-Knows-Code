library(shiny)
library(dplyr)
library(reshape)
library(ggplot2)
## Load and clean Data
scores <- as.data.frame(read.csv("data/allscores.csv", header = TRUE))

scores <- scores[scores$Season == 2016,]

teams <- as.character(unique(scores$Team))

team.stats <- scores[complete.cases(scores),] %>%
  group_by(Team) %>%
  summarize(avg = mean(Score),
            stdev = sd(Score))

week <- min(scores[is.na(scores$Score), "Week"])
sim.week <- scores[scores$Week == week,]

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
                       ,"teamBwin" = 1 - combined$Wins)[1:6,]

sim.scores <- data.frame(melt(scores.list))

shinyServer(
  function(input, output) {
    
    output$teamA <- renderPrint({
      as.character(matchups$teamA[matchups$matchup == input$var])
    })
    
    output$teamAper <- renderPrint({
      paste(round(matchups$teamAwin[matchups$matchup == input$var] * 100, 2), "%", sep = "")
    })
    
    output$teamB <- renderPrint({
      as.character(matchups$teamB[matchups$matchup == input$var])
    })
    
    output$teamBper <- renderPrint({
      paste(round(matchups$teamBwin[matchups$matchup == input$var] * 100, 2), "%", sep = "")
    })
    
    output$plot <- renderPlot({
      selected.matchup <- input$var
      teamA <- matchups$teamA[matchups$matchup == selected.matchup]
      teamB <- matchups$teamB[matchups$matchup == selected.matchup]
      
      ggplot(sim.scores[sim.scores$L1 == teamA | sim.scores$L1 == teamB, ]
                            ,aes(value, fill = L1, color = L1)) + 
                      geom_density(alpha = 0.1) +
                      xlim(0, 200)
    })
  })