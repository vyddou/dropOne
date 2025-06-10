class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post
  before_action :set_comment, only: [:destroy]

  def create
    @comment = @post.comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      redirect_to post_path(@post, anchor: 'comments-section'), notice: 'Commentaire ajouté avec succès !'
    else
      redirect_to post_path(@post, anchor: 'comments-section'), alert: 'Erreur lors de l\'ajout du commentaire.'
    end
  end

  def destroy
    if @comment.user == current_user
      @comment.destroy
      redirect_to post_path(@post, anchor: 'comments-section'), notice: 'Commentaire supprimé avec succès !'
    else
      redirect_to post_path(@post, anchor: 'comments-section'), alert: 'Vous ne pouvez pas supprimer ce commentaire.'
    end
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'Post non trouvé.'
  end

  def set_comment
    @comment = @post.comments.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to post_path(@post), alert: 'Commentaire non trouvé.'
  end

  def comment_params
    params.require(:comment).permit(:content)
  end
end