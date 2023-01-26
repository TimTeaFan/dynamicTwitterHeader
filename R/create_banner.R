# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
#       ---- Setup -----
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

# load libraries
library(ggplot2)
library(dplyr)
library(lubridate)
library(httr2)
library(rtweet)
library(ggpubr)
library(magick)
library(plotrix)
library(jsonlite)

# Twitter Token setup
# Create a token containing the Twitter keys
timteafan_token <- rtweet::create_token(
  # the name of the Twitter app
  app = "get twitter likes and followers",
  consumer_key = Sys.getenv("TIMTEAFAN_TWITTER_CONSUMER_API_KEY"),
  consumer_secret = Sys.getenv("TIMTEAFAN_TWITTER_CONSUMER_API_SECRET"),
  access_token = Sys.getenv("TIMTEAFAN_TWITTER_ACCESS_TOKEN"),
  access_secret = Sys.getenv("TIMTEAFAN_TWITTER_ACCESS_TOKEN_SECRET"),
  set_renv = FALSE
)



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
#  ----- Get current number of followers and combine with historical data -----
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

# get latest total number of twitter followers
# here we use httr2, which makes this really easy:
twit_user_req <- request("https://api.twitter.com/2/users/by/username/timteafan?user.fields=public_metrics") %>%
  req_auth_bearer_token(Sys.getenv("TIMTEAFAN_TWITTER_BEARER_TOKEN"))
twit_user_info <- twit_user_req %>% req_perform()
twit_user_info_ls <- twit_user_info %>% resp_body_json()

no_of_followers <- twit_user_info_ls$data$public_metrics$followers_count

# write latest follower data as json
no_followers_ls <- list(data = list(followers = no_of_followers))
jsonlite::write_json(no_followers_ls, "data/followers")

# read in historical follower data
# I got this data from https://analytics.twitter.com/
twitter_followers_tbl <- readRDS("data/twitter_followers.rds")

# get last date in historical follower data
last_tbl_date <- twitter_followers_tbl %>%
  slice_tail(n = 1) %>%
  pull(date)

# check if we have a new month
today <- as.Date(Sys.Date())
this_month <- floor_date(today, "month")
is_new_month <- this_month > last_tbl_date

# if new month add row with latest twitter followers
if (is_new_month) {
  upd_twitter_followers_tbl <- twitter_followers_tbl %>%
    add_row(date = this_month,
            followers = no_of_followers)
  # if same month, then update last row
  } else {
  upd_twitter_followers_tbl <- twitter_followers_tbl %>%
    rows_update(tibble(date = this_month, followers = no_of_followers), by = "date")
  }

# save updated data
saveRDS(upd_twitter_followers_tbl, "data/twitter_followers.rds")


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# ----- create plot showing Twitter followers over time -----
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

# create tbl copy for geom_point, only containing min and max
twitter_followers_last <- upd_twitter_followers_tbl %>%
  mutate(followers = if_else(date %in% range(date), followers, NA_real_))

# get x / y for latest_follower annotations
y_latest_followers <- last(upd_twitter_followers_tbl$followers)
x_latest_date <- last(upd_twitter_followers_tbl$date)

# create plot
p <- ggplot() +
  # line
  geom_line(data = upd_twitter_followers_tbl,
          aes(x = date, y = followers),
          color = "#00A3F1") +
  # points showing mix and max
  geom_point(data = twitter_followers_last,
             aes(x = date, y = followers),
             color = "#00A3F1") +
  # use date x axis and label only min and max
  scale_x_date(expand = expansion(add = c(2, 5)),
               breaks = function(x) range(x),
               date_labels = "%b %Y") +
  # use y axis without breaks
  scale_y_continuous(breaks = 0) +
  labs(y = "Twitter Followers") +
  # create minimalistic plot by getting rid of most elements
  theme(axis.text.y.left = element_blank(),
        axis.title.x.bottom = element_blank(),
        axis.title.y.left = element_text(color = "#00A3F1",
                                         size = 6),
        axis.text.x.bottom = element_text(hjust = c(0, 1),
                                          color = "#00A3F1",
                                          size = 6),
        axis.ticks.x.bottom = element_blank(),
        axis.ticks.y.left = element_blank(),
        # add arrows to axis lines
        axis.line = element_line(color = "#00A3F1",
                                 arrow = arrow(type = 'closed',
                                               length = unit(5, 'pt'))),
        panel.background = element_rect(fill = "transparent"), # bg of the panel
        plot.background = element_rect(fill = "transparent", color = NA), # bg of the plot
        panel.grid.major = element_blank(), # get rid of major grid
        panel.grid.minor = element_blank(), # get rid of minor grid
        legend.background = element_rect(fill = "transparent"), # get rid of legend bg
        legend.box.background = element_rect(fill = "transparent") # get rid of legend panel bg
  ) +
  # show curved arrow point to ...
  annotate(
    geom = "curve",
    x = x_latest_date - (diff(range(upd_twitter_followers_tbl$date)) / 15),
    y = y_latest_followers + 5,
    xend = x_latest_date - (diff(range(upd_twitter_followers_tbl$date)) / 15) / 10,
    yend = y_latest_followers + 3,
    curvature = -0.45,
    arrow = arrow(length = unit(1.5, "mm")),
    colour = "#00D24E"
  ) +
  # ... current number of followers
  annotate(geom = "text",
           x = x_latest_date - ((diff(range(upd_twitter_followers_tbl$date)) / 15) * 1.1),
           y = y_latest_followers + 10,
           label = paste(y_latest_followers, "Followers"),
           hjust = "right",
           colour = "#00D24E",
           size = 2.32)

# let's save this plot as png
ggsave("data/ggplot_follower.png",
       plot = p,
       width = 6,
       height = 2,
       units = "in",
       dpi = 250,
       bg = "transparent")



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
#        ---- Creating the banner image: Part I -----
# Initialize banner, get Twitter data and add profile images #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

# Import background, ggplot and twitter box images
background_img <- image_read("data/background_final1.png")
ggplot_img <- image_read("data/ggplot_follower.png")
twitter_box <- image_read("data/latest_followers_box.png")

# inlay background an ggplot
img <- c(background_img, ggplot_img)
img2 <- image_mosaic(img)

# compose Twitter box image on top:
img3 <- image_composite(img2,
                image_scale(twitter_box, "x200"),
                offset = "+575+095")

# get latest Twitter follower
latest_followers <- get_followers(
  "TimTeaFan",
  n = 3,
  parse = TRUE,
  verbose = TRUE,
  token = timteafan_token
)

# get Twitter pictures
latest_fol_dat <- latest_followers %>%
  rowwise() %>%
  mutate(profil_img = lookup_users(user_id, token = timteafan_token)$profile_image_url)

profil_imgs <- latest_fol_dat %>%
  mutate(profil_img = gsub("^http", "https", profil_img) %>%
           gsub("(_)(normal)(\\.jp(|e)g)$", "\\1400x400\\3", .)) %>%
  pull(profil_img) %>%
  image_read()

# function to create profile mask in form of a circle
# largely inspired (and partly copied) from this answer on StackOverflow:
# https://stackoverflow.com/a/40069492/9349302
create_profile_mask <- function(bg = "#ffffff", fill = "#000000", border = FALSE, border_color = "#ffffff") {
  png(tf <- tempfile(fileext = ".png"), 400, 400)
  par(mar = rep(0,4), yaxs = "i", xaxs = "i", bg = bg)
  plot(0, type = "n", ylim = c(0,1), xlim = c(0,1), axes = F, xlab = NA, ylab = NA)
  if (!border) {
    plotrix::draw.circle(.5, 0.5, .5,  col = fill)
  } else {
    plotrix::draw.circle(.5, 0.5, .48,  col = fill, border = border_color, lwd = 25)
  }
  dev.off()
  image_read(tf)
}

# create profile mask
mask <- create_profile_mask()

# make white transparent color
mask <- image_transparent(mask, "#ffffff")

# create transparent mask with white border
mask_border <- create_profile_mask(bg = "transparent", fill = "transparent", border = TRUE)

# function to: circle crop profile pictures (and resize if needed)
create_profile_img <- function(profil_img) {
  if (!all(attributes(profil_img[[1]])$dim[-1] == 400)) {
    profil_img <- image_resize(profil_img, "400x400!")
  }
  image_composite(image_composite(mask, profil_img, "in"), mask_border, "atop")
}

# create round profile pics of latest three followers
prof_img1 <- create_profile_img(profil_imgs[1])
prof_img2 <- create_profile_img(profil_imgs[2])
prof_img3 <- create_profile_img(profil_imgs[3])


# position profile pictures on plot
img4 <- image_composite(img3,
                        image_scale(prof_img1, "x94"),
                        offset = "+626+166")

img5 <- image_composite(img4,
                        image_scale(prof_img2, "x94"),
                        offset = "+752+166")

img6 <- image_composite(img5,
                        image_scale(prof_img3, "x94"),
                        offset = "+878+165")



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
#    ---- Creating the banner image Part II -----
# Get SO data and add image parts to finalize banner #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

# add SO image
so_box <- image_read("data/so_box.png")

img7 <- image_composite(img6,
                        image_scale(so_box, "x190"),
                        offset = "+1095+252")

# get SO data
# get SO user data
so_user_req <- request("https://api.stackexchange.com/2.3/users/9349302?order=desc&sort=reputation&site=stackoverflow")
so_user_info <- so_user_req %>% req_perform()
so_user_info_ls <- so_user_info %>% resp_body_json()

so_user_dat <- list(reputation    = so_user_info_ls$items[[1]]$reputation,
                    gold_medals   = so_user_info_ls$items[[1]]$badge_counts$gold,
                    silver_medals = so_user_info_ls$items[[1]]$badge_counts$silver,
                    bronze_medals = so_user_info_ls$items[[1]]$badge_counts$bronze)


# get SO last answer date
answer_req <- request("https://api.stackexchange.com//2.3/users/9349302/answers?order=desc&sort=activity&site=stackoverflow")
answer_info <- answer_req %>% req_perform()
answer_info_ls <- answer_info %>% resp_body_json()
latest_answer_date <- as.Date(as.POSIXct(answer_info_ls$items[[1]]$creation_date, origin = "1970-01-01"))
lst_answ_date_pretty <- format(latest_answer_date, "%d %b %Y")

# add SO data
img8 <- image_annotate(img7,
               format(so_user_dat$reputation, big.mark = ","),
               font = 'Segeo UI',
               size = 24,
               color = "white",
               weight = 600,
               location = "+1273+337")

# add SO data to plot
img9 <- image_annotate(img8,
                       so_user_dat$gold_medals,
                       font = 'Segeo UI',
                       size = 24,
                       color = "white",
                       weight = 600,
                       location = "+1273+371")

img10 <- image_annotate(img9,
                       so_user_dat$silver_medals,
                       font = 'Segeo UI',
                       size = 24,
                       color = "white",
                       weight = 600,
                       location = "+1315+371")

img11 <- image_annotate(img10,
                        so_user_dat$bronze_medals,
                        font = 'Segeo UI',
                        size = 24,
                        color = "white",
                        weight = 600,
                        location = "+1370+371")

final_plot <- image_annotate(img11,
                        lst_answ_date_pretty,
                        font = 'Segeo UI',
                        size = 21,
                        color = "white",
                        weight = 400,
                        location = "+1273+403")


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# ----- save image of final_plot -----
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
image_write(final_plot, "data/final_plot.png", format = "png")
