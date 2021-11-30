renv::restore()

# PREAMBLE ----------------------------------------------------------------

library(ggdag)
library(tidyverse)
library(dagitty)
library(ggthemes)

# GENERATING DAG USING DAGITTY.NET ----------------------------------------

#The dagitty code below was extracted from http://www.dagitty.net/dags.html

#Note: it's based on an example from the asynchronous DAG module!

dag_cand3 <- dagitty('dag {
                          Birth_Defects [outcome,pos="0.109,0.631"]
                          Difficulty_Conceiving [pos="0.117,-1.517"]
                          Genetics [pos="0.850,-0.411"]
                          PNC [pos="-0.837,-0.433"]
                          SES [pos="-1.839,-1.468"]
                          Vitamins [exposure,pos="-1.844,0.645"]
                          Difficulty_Conceiving -> PNC
                          Genetics -> Birth_Defects
                          Genetics -> Difficulty_Conceiving
                          PNC -> Birth_Defects
                          PNC -> Vitamins
                          SES -> PNC
                          SES -> Vitamins
                          Vitamins -> Birth_Defects
                          }')

#The code below produces a simple DAG (that's somewhat difficult to read!)

dag_cand3 %>% ggdag() 

# USING GGDAG AS A TOOL ---------------------------------------------------

#The code below illustrates different covariate sets that can yield an unconfounded estimate of "Vitamin's" effect on "Birth_Defects" (pursuant to your theoretical priors)

dag_cand3 %>% ggdag_adjustment_set()

#The line below illustrates the different colliders in our example:

dag_cand3 %>% ggdag_collider()

#If you're looking to identify the "ancestors" of a variable (in this case, "PNC"), you could use the following function:

dag_cand3 %>% ggdag_ancestors("PNC")

#Note: for more information about basic DAG terminology, see https://web.archive.org/web/20210306134921/http://dagitty.net/learn/graphs/index.html 

#To identify the different open paths from exposure to outcome, you could use ggdag_paths_fan() to visualize the pathways in a single, unfaceted plot:

dag_cand3 %>% ggdag_paths_fan(from = "Vitamins", to = "Birth_Defects")

#Or, you can use ggdag_paths() to visualize the different pathways using facets:

dag_cand3 %>% ggdag_paths(from = "Vitamins", to = "Birth_Defects")

#What if you conditioned on a variable — say, "PNC?"

dag_cand3 %>% ggdag_paths(from = "Vitamins", to = "Birth_Defects",
                          adjust_for = "PNC")

#There's still an open path! What's going on with path 2?

dag_cand3 %>% ggdag_adjust(var = c("PNC"), 
                           #Modifying the size of nodes by making them a tad larger:
                           node_size = 15)

#Using information derived from ggdag_adjustment_set(), let's close path 2 by conditioning on "Genetics":

dag_cand3 %>% ggdag_paths_fan(from = "Vitamins", to = "Birth_Defects",
                              adjust_for = c("PNC", "Genetics"))


# GENERATING A DAG USING GGDAG SYNTAX -------------------------------------

dag_cand3 <- dagify(#Here, we see conventional R syntax (e.g., outcome ~ predictors)
                    birth_defects ~ vitamins + pnc + genetics,
                    vitamins ~ ses + pnc,
                    pnc ~ ses + diff_conceiving,
                    diff_conceiving ~ genetics,
                    #These labels will be useful for plotting purposes down the line!
                    labels = c(#\n signals a line break
                               birth_defects = "Birth Defects\n (Outcome)",
                               vitamins = "Vitamins\n (Exposure)",
                               pnc = "Pre-Natal Care",
                               diff_conceiving = "Difficulty\n Conceiving",
                               ses = "SES",
                               genetics = "Genetics"),
                    exposure = "vitamins",
                    outcome = "birth_defects")

#Why set a seed? In the absence of pre-specified coordinates, ggdag  positions the nodes and edges differently each time — unless a seed is provided.

set.seed(905)

dag_cand3 %>% ggdag_adjustment_set()

#Creating a DAG with labels in lieu of variable names:

set.seed(905)

dag_cand3 %>% ggdag(text = FALSE, 
                    use_labels = "label")

#Finding open paths (like we did above), this time with labels:

set.seed(905)

ggdag_paths(dag_cand3, text = FALSE, use_labels = "label")


#Finding different covariate adjustment sets (like we did above), this time with labels:

ggdag_adjustment_set(dag_cand3, text = FALSE, use_labels = "label") + 
                    #An inbuilt ggplot theme optimized for DAGs/removing the legend:
                     theme_dag() + theme(legend.position = "none")

# VISUALIZING DAGS USING GGDAG + GGPLOT2 ----------------------------------

#Let's assume you want to beautify your DAG (for a paper or presentation).

#First, tidy your DAG syntax using the tidy_dagitty() function.

#Then, use the node_dconnected() function to specify the variables you'll be
#controlling to estimate the effect of vitamins on birth defects.

set.seed(905)

dag_cand3_gg <- dag_cand3 %>% tidy_dagitty(layout = "nicely") %>% 
                              node_dconnected(controlling_for = c("pnc", "ses"))

#The plot:

dag_cand3_gg %>% mutate(adjusted = #Simple way to capitalize a string:
                                  str_to_title(adjusted),
                        arrow = #Allows us to modify transparency of arrows as a function of
                                #whether or not a variable is adjusted:
                                ifelse(adjusted == "Adjusted", 0.15, 0.85)) %>% 
                 ggplot(aes(#Coordinates (i.e., where the nodes will be located)
                            x = x, y = y, xend = xend, yend = yend, 
                            #Mapping aesthetics — will vary as a function of whether
                            #a variable is adjusted or unadjusted:
                            colour = adjusted, fill = adjusted,
                            shape = adjusted)) +
                #Adds nodes to plotting area:
                 geom_dag_point() +
                #Adds arrows connecting the nodes (as specified in your DAG syntax)::
                 geom_dag_edges(aes(#Adjusts transparency of arrows:
                                    edge_alpha = arrow), edge_width = 0.5) +
                #Changes the shapes corresponding to adjusted/unadjusted.
                #To see the different baseline shape options available, go to https://web.archive.org/web/20210417085302/https://r-graphics.org/R-Graphics-Cookbook-2e_files/figure-html/FIG-SCATTER-SHAPES-CHART-1.png 
                 scale_shape_manual(values = c(22, 21)) +
                #The two lines that follow adjust the colour/fill of the nodes based on ggtheme's Economist theme:
                 scale_fill_economist() +
                 scale_colour_economist() +
                #The following line uses the logic of geom_label_repel to generate/modify your labels. 
                 geom_dag_label_repel(aes(label = label),
                                      colour = "white", 
                                      show.legend = FALSE) +
                 theme_dag() +
                 #Removes legend title:
                 theme(legend.title = element_blank()) 


# USING MANUAL COORDINATES ------------------------------------------------

#What if we want to use the same layout as our initial DAG (via DAGitty)?

#We can set our own x and y coordinates — here's how we can set up a coordinate system to replicate the layout from the asynchronous module.

coord_dag <- list(x = c(vitamins = 0, pnc = 1.5, ses = 0, diff_conceiving = 3,
                        genetics = 4, birth_defects = 3),
                  y = c(vitamins = 0, pnc = 1.5, ses = 3, diff_conceiving = 3,
                        genetics = 1.5, birth_defects = 0))

#Easiest way to implement this — re-specify your dag syntax:

dag_cand3 <- dagify(birth_defects ~ vitamins + pnc + genetics,
                    vitamins ~ ses + pnc,
                    pnc ~ ses + diff_conceiving,
                    diff_conceiving ~ genetics,
                    labels = c(birth_defects = "Birth Defects\n (Outcome)",
                               vitamins = "Vitamins\n (Exposure)",
                               pnc = "Pre-Natal Care",
                               diff_conceiving = "Difficulty\n Conceiving",
                               ses = "SES",
                               genetics = "Genetics"),
                    exposure = "vitamins",
                    outcome = "birth_defects",
                    #Key difference!
                    coords = coord_dag)

#Then, re-run lines 132-167!

# ADDITIONAL TOOLS --------------------------------------------------------

#If you want to shorten the arrows of your DAGs so that they stop before a label, you can use the following function:

shorten_dag_arrows <- function(tidy_dag, shorten_distance){
                                # Update underlying ggdag object
                                tidy_dag$data <- dplyr::mutate(tidy_dag$data, slope = (yend - y) / (xend - x), # Calculate slope of line
                                                               distance = sqrt((xend-x)^2 + (yend - y)^2), # Calculate total distance of line
                                                               proportion = shorten_distance/distance, # Calculate proportion by which to be shortened
                                                               xend = (1-proportion)*xend + (proportion*x), # Shorten xend
                                                               yend = (1-proportion)*yend + (proportion*y)) %>% # Shorten yend
                                  dplyr::select(-slope, -distance, -proportion) # Drop intermediate values
                                
                                return(tidy_dag)
                              }

#Source: https://stackoverflow.com/questions/65420136/r-how-do-you-adjust-the-arrows-in-a-ggplot-of-a-ggdag

#To use this function, you'd adjust lines 133-134 as follows:

dag_cand3_gg <- dag_cand3 %>% tidy_dagitty(layout = "nicely") %>% 
                              node_dconnected(controlling_for = c("pnc", "ses")) %>% 
                              shorten_dag_arrows(shorten_distance = 0.08)


# MORE INFORMATION/REFERENCES ---------------------------------------------

#Visit https://ggdag.malco.io/index.html
