require 'sinatra'
require 'sqlite3'
require 'bcrypt'
require 'slim'

enable :sessions

get("/") do
    db = SQLite3::Database.new("db/db.sqlite3")
    db.results_as_hash = true
    tips = db.execute("SELECT * FROM tips")
    likes = db.execute("SELECT * FROM likes")
    tips_likes = {}
    tips.each do |tip|
        tips_likes[tip["id"].to_s] = 0
    end
    likes.each do |like|
        tips_likes[like["tip_id"]] += 1
    end
    
    temp = tips
    tips = []
    while temp.size > 0
        highest_index = -1
        highest_value = -1
        tip_index = 0
        while tip_index < temp.size
            tip = temp[tip_index]
            tip_value = tips_likes[tip["id"].to_s].to_i
            if tip_value > highest_value
                highest_index = tip_index
                highest_value = tip_value
            end
            tip_index += 1
        end
        tip = temp[highest_index]
        tips.push(tip)
        temp.delete(tip)
    end

    slim(:index, locals:{"tips" => tips, "tips_likes" => tips_likes})
end

post("/post_tip/?") do
    title = params[:title]
    message = params[:message]
    user_id = session[:user_id].to_s

    if user_id == nil || message.empty?
        redirect("/")
    end

    db = SQLite3::Database.new("db/db.sqlite3")
    db.results_as_hash = true

    db.execute("INSERT INTO tips(title, message, user_id) VALUES(?,?,?)", [title, message, user_id])

    redirect("/")
end

get("/register/?") do
    slim(:register)
end

post("/register/?") do
    username = params[:username]
    real_name = params[:real_name]
    password = params[:password]
    password2 = params[:password2]

    db = SQLite3::Database.new("db/db.sqlite3")
    db.results_as_hash = true

    if password != password2
        redirect("/register/")
    end

    conflicts = db.execute("SELECT * FROM users WHERE username = ?", [username])
    if conflicts.size() > 0
        redirect("/register/")
    end

    hash = BCrypt::Password.create(password)
    db.execute("INSERT INTO users(username, real_name, password) VALUES(?,?,?)", [username, real_name, hash])

    user_id = db.execute("SELECT id FROM users WHERE username = ?", [username]).first 
    session[:user_id] = user_id

    redirect("/")
end

get("/login/?") do
    slim(:login)
end

post("/login/?") do
    username = params[:username]
    password = params[:password]
    
    db = SQLite3::Database.new("db/db.sqlite3")
    db.results_as_hash = true

    users = db.execute("SELECT * FROM users WHERE username = ?", [username])
    if users.size() == 0
        redirect("/login")
    end

    user = users.first
    if BCrypt::Password.new(user["password"]) != password
        redirect("/login")
    end

    session[:user_id] = user["id"]
    redirect("/")
end

get("/logout/?") do
    session[:user_id] = nil
    redirect("/")
end

get("/liketips/:id") do
    tip_id = params[:id]
    user_id = session[:user_id]
    if user_id == nil
        redirect("/")
    end

    db = SQLite3::Database.new("db/db.sqlite3")
    db.results_as_hash = true

    likes = db.execute("SELECT * FROM likes WHERE user_id = ? AND tip_id = ?", [user_id, tip_id])
    if likes.size() == 0
        db.execute("INSERT INTO likes(user_id, tip_id) VALUES(?,?)", [user_id, tip_id])
        puts "Tip liked"
    else
        db.execute("DELETE FROM likes WHERE user_id = ? AND tip_id = ?", [user_id, tip_id])
        puts "Tip unliked"
    end

    redirect("/")
end

get("/liketipsaccount/:id") do
    tip_id = params[:id]
    user_id = session[:user_id]
    if user_id == nil
        redirect("/")
    end

    db = SQLite3::Database.new("db/db.sqlite3")
    db.results_as_hash = true

    likes = db.execute("SELECT * FROM likes WHERE user_id = ? AND tip_id = ?", [user_id, tip_id])
    if likes.size() == 0
        db.execute("INSERT INTO likes(user_id, tip_id) VALUES(?,?)", [user_id, tip_id])
        puts "Tip liked"
    else
        db.execute("DELETE FROM likes WHERE user_id = ? AND tip_id = ?", [user_id, tip_id])
        puts "Tip unliked"
    end

    redirect("/account")
end

get("/account/?") do
    user_id = session[:user_id].to_s
    puts user_id
    if user_id == nil
        redirect("/")
    end

    db = SQLite3::Database.new("db/db.sqlite3")
    db.results_as_hash = true
    user = db.execute("SELECT * FROM users WHERE id = ?", [user_id]).first

    tips_likes = db.execute("SELECT * FROM likes WHERE user_id = ?", [user_id])
    puts "Liked tips IDs: " + tips_likes.to_s
    liked_tips = []
    for id in tips_likes
        tip_id = id["tip_id"].to_i
        likes = db.execute("SELECT * FROM tips WHERE id = ?", [tip_id])
        if likes.size() != 0
            liked_tips.push(likes.first)
        end
    end

    slim(:account, locals:{"user" => user, "liked_tips" => liked_tips, "tips_likes" => tips_likes})
end